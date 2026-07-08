suppressWarnings(suppressMessages({
  source("R/tv_ball_sampling.R"); source("R/gradient_correlation.R")
  source("R/tv_ball_correlation_IF_adaptive.R")}))
gen <- function(n){X<-sample(c(-2,-1,0,1,2),n,TRUE,prob=c(.05,.25,.40,.25,.05));A<-rbinom(n,1,0.5)
  S<-(1.0+0.5*X)*A+rnorm(n,0,0.5);Y<-(0.25-0.3*X)*A+0.9*S-0.1*S*X+rnorm(n,0,0.5);data.frame(X=X,A=A,S=S,Y=Y)}
run1<-function(seed,n=3000){set.seed(seed);d<-gen(n)
  r<-tv_ball_correlation_IF_adaptive(d,lambda=0.3,method="importance_weighting",
     M_start=800,M_increment=1,M_max=800,tolerance=1,n_stable=2,burn_in=300,thin=3,verbose=FALSE)
  c(rho=r$rho_hat,se=r$se,lo=r$ci_lower,hi=r$ci_upper)}
set.seed(1); R<-60
res<-t(sapply(1:R,function(s) run1(5000+s)))
res<-res[is.finite(res[,"rho"])&is.finite(res[,"se"]),,drop=FALSE]
rb<-mean(res[,"rho"]);esd<-sd(res[,"rho"]);mse<-mean(res[,"se"])
sink("/tmp/calib_result.txt")
cat(sprintf("n=3000 reps=%d\nmean_rho=%.4f  emp_SD=%.4f  mean_IF_SE=%.4f  SE/SD=%.3f\n",
    nrow(res),rb,esd,mse,mse/esd))
cat(sprintf("coverage of mean_rho: %.1f%%\n",100*mean(res[,"lo"]<=rb&rb<=res[,"hi"])))
sink()
