suppressMessages(source("R/tv_ball_sampling.R"))
set.seed(1)
K<-5; xl<- -2:2; pX<-c(.05,.25,.40,.25,.05); tauS<-0.5*xl
gen <- function(n){X<-sample(xl,n,TRUE,prob=pX);A<-rbinom(n,1,.5)
  S<-tauS[match(X,xl)]*A+rnorm(n,sd=.5);data.frame(X=X,A=A,S=S)}
P0<-pX; Q<-sample_tv_ball(P0,0.3,M=4000,burn_in=300,thin=2,verbose=FALSE); Sig<-cov(Q)
cell_IF<-function(d){n<-nrow(d);IF<-matrix(0,n,K);cell<-match(d$X,xl)
  for(k in 1:K){ink<-cell==k;pk<-mean(ink);ek<-mean(d$A[ink])
    m1<-mean(d$S[ink&d$A==1]);m0<-mean(d$S[ink&d$A==0]);idx<-which(ink)
    IF[idx,k]<-(1/pk)*(d$A[idx]*(d$S[idx]-m1)/ek-(1-d$A[idx])*(d$S[idx]-m0)/(1-ek))}
  IF}
# chi_aa centered with TRUE tau and TRUE Sigma, big n: should be mean ~0
# key subtlety: the IF must be centered per-cell; test mean over many big datasets
means<-numeric(50)
for(r in 1:50){ d<-gen(20000); IF<-cell_IF(d)
  # use TRUE tauS (not estimated) in the linear part; centering constant tau'Sig tau
  chi<-2*as.numeric(IF %*% (Sig%*%tauS)) - as.numeric(t(tauS)%*%Sig%*%tauS)
  means[r]<-mean(chi) }
cat(sprintf("chi_aa (true tau, n=20000): mean over 50 datasets = %.5f, sd of means = %.5f\n",
  mean(means), sd(means)))
cat(sprintf("  is mean within 2 SE of 0? %s\n", abs(mean(means)) < 2*sd(means)/sqrt(50)))
# The centering constant: E[2 IF'(Sig tau)] should be 0 since E[IF]=0 per cell.
# The -tau'Sig tau is a CONSTANT, so chi has mean -tau'Sig tau, NOT 0!
cat(sprintf("\ntau'Sig tau = %.4f (this constant is the non-zero mean if included)\n",
  as.numeric(t(tauS)%*%Sig%*%tauS)))
cat("NOTE: chi_ab in the proof is the EIF whose mean is 0 for the CENTERED functional;\n")
cat("the -Theta_ab constant is the plug-in value, so the DEBIASING score P_n chi has\n")
cat("mean E[2 IF'(Sig tau)] = 0. The -Theta term belongs with the plug-in, not the score.\n")
