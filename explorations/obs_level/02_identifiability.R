# =============================================================================
# 02_identifiability.R -- is the observation-level estimand IDENTIFIED from data?
# The obs-level correlation depends on the within-X (co)variances of individual
# effects: v_S(x)=Var(tau_S|x), v_Y(x)=Var(tau_Y|x), c_SY(x)=Cov(tau_S,tau_Y|x).
# Question: can these be recovered from a single RCT, or are they confounded with
# noise / non-identified?
# =============================================================================
set.seed(20260709)

# In an RCT we observe, within cell x and arm a:
#   Var(S | A=1,x) = Var(tau_S|x) + Var(S(0)|x) + noise ...  (potential-outcome var)
# Actually: S = tau_S*A + base_S + eps.  Within x, arm 1: S = tau_S(x,U)+base+eps.
#   Var(S|A=1,x) = Var(tau_S|x) + Var(base_S|x) + sd_eps^2
#   Var(S|A=0,x) =                Var(base_S|x) + sd_eps^2
# => Var(tau_S|x) = Var(S|A=1,x) - Var(S|A=0,x)   IF base_S,eps indep of tau_S|x.
# The CROSS term Cov(tau_S,tau_Y|x) is the killer: needs joint (S,Y) potential
# outcomes on the SAME unit under treatment, minus control -- but tau_S and tau_Y
# are never both observed as effects on one unit (each unit is one arm).

gen <- function(n, aS,bS, aY,bY, base_cor=0, sdS=0.5,sdY=0.5){
  X<-sample(-2:2,n,TRUE,prob=c(.05,.25,.40,.25,.05)); U<-rnorm(n); A<-rbinom(n,1,.5)
  # baselines (present in both arms), possibly correlated across S,Y
  bZ<-MASS::mvrnorm(n,c(0,0),matrix(c(1,base_cor,base_cor,1),2))
  tauS<-aS*X+bS*U; tauY<-aY*X+bY*U
  S<-tauS*A + bZ[,1] + rnorm(n,sd=sdS)
  Y<-tauY*A + bZ[,2] + rnorm(n,sd=sdY)
  data.frame(X=X,A=A,S=S,Y=Y,tauS=tauS,tauY=tauY,U=U)
}

d <- gen(50000, aS=0.5,bS=0.5, aY=0.8,bY=-0.8, base_cor=0.6)

# (1) Var(tau_S|x): recoverable as Var(S|A=1,x)-Var(S|A=0,x)?
cat("Var(tau_S|x): TRUE vs [Var(S|A1,x)-Var(S|A0,x)]\n")
for(x in -2:2){ i<-d$X==x
  vtrue<-var(d$tauS[i]); vhat<-var(d$S[i&d$A==1])-var(d$S[i&d$A==0])
  cat(sprintf("  x=%+d: true=%.3f  est=%.3f\n",x,vtrue,vhat)) }

# (2) Cov(tau_S,tau_Y|x): can we get it? We'd need Cov of the two EFFECTS within x.
# Try the naive cross-arm-variance analogue: Cov(S,Y|A1,x)-Cov(S,Y|A0,x)
cat("\nCov(tau_S,tau_Y|x): TRUE vs [Cov(S,Y|A1,x)-Cov(S,Y|A0,x)]\n")
for(x in -2:2){ i<-d$X==x
  ctrue<-cov(d$tauS[i],d$tauY[i])
  chat<-cov(d$S[i&d$A==1],d$Y[i&d$A==1])-cov(d$S[i&d$A==0],d$Y[i&d$A==0])
  cat(sprintf("  x=%+d: true=%.3f  est=%.3f\n",x,ctrue,chat)) }
