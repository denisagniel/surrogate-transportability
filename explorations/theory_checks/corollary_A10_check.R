# Corollary A10 numeric check: does the general bilinear-functional EIF chi_ab,
# specialized to finite X (C->Sigma, per-cell AIPW IF), reproduce the discrete
# influence function used by the finite-support estimator?
#
# General chi_ab(O) = (Sigma tau_b)' IF_a(O) + (Sigma tau_a)' IF_b(O) - tau_a'Sigma tau_b
# where IF_a(O) is the K-vector of per-cell CATE influence contributions.
# For a=b (variance term): chi_aa = 2 (Sigma tau_a)' IF_a - tau_a'Sigma tau_a.
# Its population 2nd moment contribution reduces to tr(Sigma V), V=E[IF_a IF_a'].
# Check: E[chi_aa]=0 and the plug-in bias E[tau_hat' Sigma tau_hat - tau'Sigma tau]
# = tr(Sigma V) matches the general -E[correction].
suppressMessages(source("R/tv_ball_sampling.R"))
set.seed(20260709)
# discrete DGP with known per-cell effects
K <- 5; xl <- -2:2; pX <- c(.05,.25,.40,.25,.05)
tauS <- 0.5*xl                       # true cell CATEs
n <- 4000
gen <- function(n){ X<-sample(xl,n,TRUE,prob=pX); A<-rbinom(n,1,.5)
  S <- tauS[match(X,xl)]*A + rnorm(n,sd=.5); data.frame(X=X,A=A,S=S) }
# Sigma from the sampler
P0<-pX; Q<-sample_tv_ball(P0,0.3,M=3000,burn_in=200,thin=2,verbose=FALSE); Sig<-cov(Q)

# per-cell CATE IF for one dataset: IF_a(O_i)[k] = 1{X=k}/p_k [A(S-m1k)/e - (1-A)(S-m0k)/(1-e)]
cell_IF <- function(d){
  n<-nrow(d); IF<-matrix(0,n,K); cell<-match(d$X,xl)
  for(k in 1:K){ ink<-cell==k; pk<-mean(ink); ek<-mean(d$A[ink])
    m1<-mean(d$S[ink&d$A==1]); m0<-mean(d$S[ink&d$A==0]); idx<-which(ink)
    IF[idx,k]<-(1/pk)*(d$A[idx]*(d$S[idx]-m1)/ek-(1-d$A[idx])*(d$S[idx]-m0)/(1-ek)) }
  IF }

# (1) plug-in bias of tau'Sigma tau vs tr(Sigma V) prediction
B<-400; naive<-numeric(B); trSV<-numeric(B)
for(b in 1:B){ d<-gen(n)
  cellmean<-function(k){y1<-d$S[match(d$X,xl)==k&d$A==1];y0<-d$S[match(d$X,xl)==k&d$A==0];mean(y1)-mean(y0)}
  th<-sapply(1:K,cellmean)
  naive[b]<-as.numeric(t(th)%*%Sig%*%th)
  IF<-cell_IF(d); V<-cov(IF)/n            # Var of the cell-mean vector
  trSV[b]<-sum(diag(Sig%*%V)) }
truth<-as.numeric(t(tauS)%*%Sig%*%tauS)
cat(sprintf("tau'Sigma tau  true=%.4f\n", truth))
cat(sprintf("plug-in mean   =%.4f  (bias %+.4f)\n", mean(naive), mean(naive)-truth))
cat(sprintf("mean tr(SigmaV)=%.4f   <- general chi predicts this IS the bias\n", mean(trSV)))
cat(sprintf("bias / tr(SigmaV) ratio = %.2f  (should be ~1)\n", (mean(naive)-truth)/mean(trSV)))

# (2) general chi_aa mean-zero check on one dataset
d<-gen(n); IF<-cell_IF(d)
cellmean<-function(k){y1<-d$S[match(d$X,xl)==k&d$A==1];y0<-d$S[match(d$X,xl)==k&d$A==0];mean(y1)-mean(y0)}
th<-sapply(1:K,cellmean)
chi_aa <- 2*as.numeric(IF %*% (Sig%*%th)) - as.numeric(t(th)%*%Sig%*%th)
cat(sprintf("\ngeneral chi_aa: mean=%.5f (should be ~0)\n", mean(chi_aa)))
