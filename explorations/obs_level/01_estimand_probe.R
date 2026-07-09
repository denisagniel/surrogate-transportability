# =============================================================================
# 01_estimand_probe.R -- is there a principled OBSERVATION-LEVEL estimand distinct
# from the X-level correlation, and is it identifiable from one study?
# EXPLORATION. DGP has UNMEASURED within-X effect heterogeneity (U), so we know
# ground truth for both the X-level and the individual-level quantities.
# =============================================================================
set.seed(20260709)

# DGP: individual effects tau_S(X,U), tau_Y(X,U). U ~ N(0,1) unobserved.
#   tau_S(x,u) = aS*x + bS*u
#   tau_Y(x,u) = aY*x + bY*u + cY*x   (direct dependence on x too)
# X in {-2..2}. The KEY knobs: bS,bY = within-X (unmeasured) heterogeneity slopes.
# If bS=bY=0 -> no within-X heterogeneity -> A0 holds exactly.
gen <- function(n, aS,bS, aY,bY, sdS=0.5, sdY=0.5){
  X <- sample(-2:2, n, TRUE, prob=c(.05,.25,.40,.25,.05))
  U <- rnorm(n)                          # UNOBSERVED effect modifier
  A <- rbinom(n,1,0.5)
  tauS <- aS*X + bS*U
  tauY <- aY*X + bY*U
  S <- tauS*A + rnorm(n,sd=sdS)
  Y <- tauY*A + rnorm(n,sd=sdY)
  data.frame(X=X,U=U,A=A,S=S,Y=Y,tauS=tauS,tauY=tauY)
}

# Two estimands, computed from TRUTH (using U, which we know here):
# X-LEVEL: effects are tau_S(x)=E[tau|x]=aS*x (U averaged out). Correlate across
#   compositional futures (reweight X only).
# OBS-LEVEL: effects vary per-individual; correlate across futures that can also
#   reweight U|X.
# We compute each as the correlation of (Delta_S,Delta_Y) over a class of studies.

# reweight-by-X future studies (compositional): draw random weights on the 5 X-cells
xlevel_cor <- function(aS,aY, xs=-2:2, nrep=4000){
  tS <- aS*xs; tY <- aY*xs                # X-level cell effects (U averaged out)
  dS<-dY<-numeric(nrep)
  for(r in 1:nrep){ q<-rexp(5); q<-q/sum(q); dS[r]<-sum(q*tS); dY[r]<-sum(q*tY) }
  cor(dS,dY)
}
# reweight-by-(X,U) future studies (individual): draw weights over a fine (x,u) grid
obslevel_cor <- function(aS,bS,aY,bY, xs=-2:2, nrep=4000, nu=25){
  us <- qnorm(seq(.02,.98,length.out=nu)); pu <- rep(1/nu,nu)
  grid <- expand.grid(x=xs,u=us); G<-nrow(grid)
  tS <- aS*grid$x + bS*grid$u; tY <- aY*grid$x + bY*grid$u
  base <- rep(c(.05,.25,.40,.25,.05),each=nu)*rep(pu,times=5)  # P0 over (x,u)
  dS<-dY<-numeric(nrep)
  for(r in 1:nrep){ q<-base*rexp(G); q<-q/sum(q); dS[r]<-sum(q*tS); dY[r]<-sum(q*tY) }
  cor(dS,dY)
}

cat("Scenario A: NO within-X heterogeneity (bS=bY=0) -> A0 holds\n")
cat(sprintf("  X-level cor   = %.3f\n", xlevel_cor(aS=0.5, aY=0.8)))
cat(sprintf("  obs-level cor = %.3f\n", obslevel_cor(aS=0.5,bS=0, aY=0.8,bY=0)))

cat("\nScenario B: within-X heterogeneity ALIGNED with X-effects (bS=0.5,bY=0.8)\n")
cat(sprintf("  X-level cor   = %.3f\n", xlevel_cor(aS=0.5, aY=0.8)))
cat(sprintf("  obs-level cor = %.3f\n", obslevel_cor(aS=0.5,bS=0.5, aY=0.8,bY=0.8)))

cat("\nScenario C: within-X heterogeneity OPPOSED to X-effects (bS=0.5,bY=-0.8)\n")
cat(sprintf("  X-level cor   = %.3f\n", xlevel_cor(aS=0.5, aY=0.8)))
cat(sprintf("  obs-level cor = %.3f\n", obslevel_cor(aS=0.5,bS=0.5, aY=0.8,bY=-0.8)))

cat("\nScenario D: X-effects UNcorrelated, but within-X strongly correlated\n")
cat(sprintf("  X-level cor   = %.3f\n", xlevel_cor(aS=0.5, aY=-0.5)))   # opposing X slopes
cat(sprintf("  obs-level cor = %.3f\n", obslevel_cor(aS=0.5,bS=0.9, aY=-0.5,bY=0.9)))
