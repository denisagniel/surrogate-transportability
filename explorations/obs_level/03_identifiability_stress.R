# Stress the identifiability: does the difference-in-covariances estimator of
# Cov(tau_S,tau_Y|x) survive when (a) effects correlate with baselines, and
# (b) baseline covariance differs from what the estimator assumes?
# This is the realistic case; if it fails here, obs-level is NOT point-identified.
suppressMessages(library(MASS)); set.seed(20260709)

gen <- function(n, aS,bS,aY,bY, eff_base_cor=0){
  X<-sample(-2:2,n,TRUE,prob=c(.05,.25,.40,.25,.05)); U<-rnorm(n); A<-rbinom(n,1,.5)
  base<-mvrnorm(n,c(0,0),matrix(c(1,0.6,0.6,1),2))
  # effects correlated WITH baseline (realistic): larger baseline -> larger effect
  tauS<-aS*X+bS*U + eff_base_cor*base[,1]
  tauY<-aY*X+bY*U + eff_base_cor*base[,2]
  S<-tauS*A+base[,1]+rnorm(n,sd=.5); Y<-tauY*A+base[,2]+rnorm(n,sd=.5)
  data.frame(X=X,A=A,S=S,Y=Y,tauS=tauS,tauY=tauY)
}
probe <- function(eff_base_cor){
  d<-gen(60000, .5,.5, .8,-.8, eff_base_cor=eff_base_cor)
  errs<-numeric(0)
  for(x in -2:2){ i<-d$X==x
    ctrue<-cov(d$tauS[i],d$tauY[i])
    chat<-cov(d$S[i&d$A==1],d$Y[i&d$A==1])-cov(d$S[i&d$A==0],d$Y[i&d$A==0])
    errs<-c(errs, chat-ctrue) }
  cat(sprintf("eff-base corr=%.1f : mean |Cov_hat - Cov_true| over cells = %.3f  (true~%.2f)\n",
      eff_base_cor, mean(abs(errs)), cov(d$tauS,d$tauY)))
}
cat("Recovery of within-X Cov(tau_S,tau_Y) as effect-baseline dependence grows:\n")
for(ebc in c(0, 0.5, 1.0)) probe(ebc)
cat("\n(If error grows with effect-baseline correlation, the cross-term is NOT\n identified without assuming effects independent of baselines within X.)\n")
