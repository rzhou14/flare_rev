#----------------------------------------------------------------------------------#
# Package: flare                                                                   #
# flare.slim(): The user interface for slim()                                      #
# Author: Xingguo Li                                                               #
# Email: <xingguo.leo@gmail.com>                                                   #
# Date: Mar 16th 2014                                                              #
# Version: 1.2.0                                                                   #
#----------------------------------------------------------------------------------#

slim <- function(X, 
                 Y_rachel, 
                 Y_rachel_column = 1,
                 lambda = NULL,
                 nlambda = NULL,
                 lambda.min.value = NULL,
                 lambda.min.ratio = NULL,
                 rho = 1,
                 method="dantzig",
                 q = 2,
                 res.sd = FALSE,
                 prec = 1e-5,
                 max.ite = 1e5,
                 verbose = TRUE)
{
  if(method!="dantzig" && method!="lq" && method!="lasso"){
    cat("\"method\" must be dantzig, lasso or lq.\n")
    return(NULL)
  }
  if(method=="lq"){
    if(q<1 || q>2){
      cat("q must be in [1, 2] when method = \"lq\".\n")
      return(NULL)
    }
  }
  if(verbose) {
    cat("Sparse Linear Regression with L1 Regularization.\n")
  }
  
  
  
  n = nrow(X)  #*****************************************
  d = ncol(X)  #****************************************
  
  if(n==0 || d==0) {
    cat("No data input.\n")
    return(NULL)
  }
  
  #rachel read below***************************
  maxdf = max(n,d)
  xm=matrix(rep(colMeans(X),n),nrow=n,ncol=d,byrow=T)
  x1=X-xm
  sdxinv=1/sqrt(colSums(x1^2)/(n-1))
  xx=x1*matrix(rep(sdxinv,n),nrow=n,ncol=d,byrow=T)
  ym=NA
  
  #y1=Y-ym
  Y_rachel_ncol = dim(Y_rachel)[2]
  y1 = Y_rachel * matrix(rep(sdxinv,Y_rachel_ncol),nrow=d,ncol=Y_rachel_ncol)
  
  #rachel read above***************************
  if(res.sd == TRUE){
    sdy=sqrt(sum(y1^2)/(n-1))
    yy=y1/sdy
  }else{
    sdy = 1
    yy = y1
  }
  intercept = FALSE
  
  if(intercept){
    xx = cbind(rep(1, nrow(xx)), xx)
    X = cbind(rep(1, nrow(X)), X)
    d = d+1
  }
  
  if(!is.null(lambda)) nlambda = length(lambda)
  if(is.null(lambda)){
    if(is.null(nlambda))
      nlambda = 5
    if(method=="dantzig"){
      if(intercept)
        lambda.max = max(abs(crossprod(xx[,2:d],yy/n)))
      else
        #lambda.max = max(abs(crossprod(xx,yy/n)))
        lambda.max = max(abs(yy/n))
    }
    if(method=="lq"){
      if(q==2){
        if(intercept)
          lambda.max = max(abs(crossprod(xx[,2:d],yy/sqrt(sum(yy^2))/sqrt(n))))
        else
          lambda.max = max(abs(crossprod(xx,yy/sqrt(sum(yy^2))/sqrt(n))))
      }else{
        if(q==1){
          if(intercept)
            lambda.max = max(abs(crossprod(xx[,2:d],sign(yy)/n)))
          else
            lambda.max = max(abs(crossprod(xx,sign(yy)/n)))
        }else{
          if(intercept){
            lambda.max = max(abs(crossprod(xx[,2:d],sign(yy)*(abs(yy)^(q-1))/(sum(abs(yy)^q)^((q-1)/q))/n^(1/q))))# 1<=q<=2
          }else{
            lambda.max = max(abs(crossprod(xx,sign(yy)*(abs(yy)^(q-1))/(sum(abs(yy)^q)^((q-1)/q))/n^(1/q)))) # 1<=q<=2
          }
        }
      }
    }
    if(method=="lasso"){
      if(intercept)
        lambda.max = max(abs(crossprod(xx[,2:d],yy/n)))
      else
        lambda.max = max(abs(crossprod(xx,yy/n)))
    }
    if(method=="dantzig"){
      if(is.null(lambda.min.ratio)){
        lambda.min.ratio = 0.5
      }
      if(is.null(lambda.min.value)){
        lambda.min.value = lambda.min.ratio*lambda.max
      }
    }else{
      if(is.null(lambda.min.value)){
        lambda.min.value = sqrt(log(d)/n)
      }else{
        if(is.null(lambda.min.ratio)){
          lambda.min.ratio = lambda.min.value/lambda.max
        }
      }
    }
    if(lambda.max<lambda.min.value){
      lambda.max = 1
      lambda.min.value = 0.4
    }
    lambda = exp(seq(log(lambda.max), log(lambda.min.value), length = nlambda))
    rm(lambda.max,lambda.min.value,lambda.min.ratio)
    gc()
  }
  if(is.null(rho))
    rho = 1
  begt=Sys.time()
  
  yy_run = as.matrix(yy[,Y_rachel_column])
  
  if(method=="dantzig"){ # dantzig
    if(d>=n)
      
      out = slim.dantzig.ladm.scr(yy_run, xx, lambda, nlambda, n, d, maxdf, rho, max.ite, prec, intercept, verbose)
    else
      out = slim.dantzig.ladm.scr2(yy_run, xx, lambda, nlambda, n, d, maxdf, rho, max.ite, prec, intercept, verbose)
    q = "infty"
  }
  if(method=="lq") {#  && q!=2 && q!="lasso"
    if(q==1) # lad lasso
      out = slim.lad.ladm.scr.btr(yy, xx, lambda, nlambda, n, d, maxdf, rho, max.ite, prec, intercept, verbose)
    if(q==2) # sqrt lasso
      out = slim.sqrt.ladm.scr(yy, xx, lambda, nlambda, n, d, maxdf, rho, max.ite, prec, intercept, verbose)
    if(q>1 && q<2) # lq lasso
      out = slim.lq.ladm.scr.btr(yy, xx, q, lambda, nlambda, n, d, maxdf, rho, max.ite, prec, intercept, verbose)
  }
  if(method=="lasso")
    out = slim.lasso.ladm.scr(yy, xx, lambda, nlambda, n, d, maxdf, max.ite, prec, intercept, verbose)
  runt=Sys.time()-begt
  
  df=rep(0,nlambda)
  if(intercept){
    for(i in 1:nlambda)
      df[i] = sum(out$beta[[i]][2:d]!=0)
  }else{
    for(i in 1:nlambda)
      df[i] = sum(out$beta[[i]]!=0)
  }
  
  est = list()
  intcpt0=matrix(0,nrow=1,ncol=nlambda)
  intcpt=matrix(0,nrow=1,ncol=nlambda)
  if(intercept){
    beta1=matrix(0,nrow=d-1,ncol=nlambda)
    for(k in 1:nlambda){
      tmp.beta = out$beta[[k]][2:d]
      beta1[,k]=sdxinv*tmp.beta*sdy
      intcpt[k] = ym-as.numeric(xm[1,]%*%beta1[,k])+out$beta[[k]][1]*sdy
      intcpt0[k] = intcpt[k]
    }
  }else{
    beta1=matrix(0,nrow=d,ncol=nlambda)
    for(k in 1:nlambda){
      tmp.beta = out$beta[[k]]
      intcpt0[k] = 0
      beta1[,k] = sdxinv*tmp.beta*sdy
      intcpt[k] = ym-as.numeric(xm[1,]%*%beta1[,k])
    }
  }
  
  est$beta0 = out$beta
  est$beta = beta1
  est$intercept = intcpt
  est$intercept0 = intcpt0
  est$Y = NA
  est$X = X
  est$lambda = lambda
  est$nlambda = nlambda
  est$df = df
  est$method = method
  est$q = q
  est$ite =out$ite
  est$verbose = verbose
  est$runtime = runt
  class(est) = "slim"
  if(verbose) print(est)
  return(est)
}






########################################################################################

print.slim <- function(x, ...)
{  
  cat("\n")
  cat("slim options summary: \n")
  cat(x$nlambda, "lambdas used:\n")
  print(signif(x$lambda,digits=3))
  cat("Method =", x$method, "\n")
  if(x$method=="lq"){
    if(x$q==1){
      cat("q =",x$q," loss, LAD Lasso\n")
    } else {
      if(x$q==2)
        cat("q =",x$q,"loss, SQRT Lasso\n")
      else
        cat("q =",x$q,"loss\n")
    }
  }
  cat("Degree of freedom:",min(x$df),"----->",max(x$df),"\n")
  if(units.difftime(x$runtime)=="secs") unit="secs"
  if(units.difftime(x$runtime)=="mins") unit="mins"
  if(units.difftime(x$runtime)=="hours") unit="hours"
  cat("Runtime:",x$runtime,unit,"\n")
}

plot.slim <- function(x, ...)
{
  matplot(x$lambda, t(x$beta), type="l", main="Regularization Path",
          xlab="Regularization Parameter", ylab="Coefficient")
}

coef.slim <- function(object, lambda.idx = c(1:3), beta.idx = c(1:3), ...)
{
  lambda.n = length(lambda.idx)
  beta.n = length(beta.idx)
  cat("\n Values of estimated coefficients: \n")
  cat(" index     ")
  for(i in 1:lambda.n){
    cat("",formatC(lambda.idx[i],digits=5,width=10),"")
  }
  cat("\n")
  cat(" lambda    ")
  for(i in 1:lambda.n){
    cat("",formatC(object$lambda[lambda.idx[i]],digits=4,width=10),"")
  }
  cat("\n")
  cat(" intercept ")
  for(i in 1:lambda.n){
    cat("",formatC(object$intercept[lambda.idx[i]],digits=4,width=10),"")
  }
  cat("\n")
  for(i in 1:beta.n){
    cat(" beta",formatC(beta.idx[i],digits=5,width=-5))
    for(j in 1:lambda.n){
      cat("",formatC(object$beta[beta.idx[i],lambda.idx[j]],digits=4,width=10),"")
    }
    cat("\n")
  }
}
predict.slim <- function(object, newdata, lambda.idx = c(1:3), Y.pred.idx = c(1:5), ...)
{
  pred.n = nrow(newdata)
  lambda.n = length(lambda.idx)
  Y.pred.n = length(Y.pred.idx)
  intcpt = matrix(rep(object$intercept[,lambda.idx],pred.n),nrow=pred.n,
                  ncol=lambda.n,byrow=T)
  Y.pred = newdata%*%object$beta[,lambda.idx] + intcpt
  cat("\n Values of predicted responses: \n")
  cat("   index   ")
  for(i in 1:lambda.n){
    cat("",formatC(lambda.idx[i],digits=5,width=10),"")
  }
  cat("\n")
  cat("   lambda  ")
  for(i in 1:lambda.n){
    cat("",formatC(object$lambda[lambda.idx[i]],digits=4,width=10),"")
  }
  cat("\n")
  for(i in 1:Y.pred.n){
    cat("    Y",formatC(Y.pred.idx[i],digits=5,width=-5))
    for(j in 1:lambda.n){
      cat("",formatC(Y.pred[Y.pred.idx[i],j],digits=4,width=10),"")
    }
    cat("\n")
  }
  return(list(Y.pred))
}


ihmm <- function(Y, G, S, mediation_setting = 'incomplete', tuning_method = 'aic', lam_list = NA, 
                 min.ratio = 0.1, n.lambda = 5, center = TRUE) {
  
  library(scalreg)
  
  n = dim(G)[1]
  p = dim(G)[2]
  q = dim(S)[2]
  
  if (center == TRUE) {
    
    Y = Y - mean(Y)
    sm=matrix(rep(colMeans(S),n),nrow=n,ncol=q,byrow=T)
    S=S-sm
    gm=matrix(rep(colMeans(G),n),nrow=n,ncol=p,byrow=T)
    G=G-gm
    
  }
  
  if (mediation_setting == 'incomplete') {
    X = cbind(G,S)
    
    sigma_SS_hat = t(S)%*%S/n
    Sigma_SG_hat = t(S)%*%G/n
    Sigma_GG_hat = t(G)%*%G/n
    Sigma_XX_hat = t(X)%*%X/n
    
    sigma_SS_hat_inverse = solve(sigma_SS_hat)
    
    result_scalreg = scalreg(X,Y)
    alpha_hat = result_scalreg$co
    sigma1_hat = result_scalreg$hsigma
    
    if(sigma1_hat > 10) {
      result_scalreg = scalreg(round(X,2),round(Y,2))
      alpha_hat = result_scalreg$co
      sigma1_hat = result_scalreg$hsigma
    }
    
    sigma_hat = summary(lm(Y~S))$sigma
    sigma2_hat = sqrt(max(sigma_hat^2-sigma1_hat^2,0))
    lambda.k_hat = t(X)%*%(Y-X%*%alpha_hat)/n
    
    Dhat = matrix(0,2*q,p+q)
    Dhat[1:q,1:p] = Sigma_SG_hat
    Dhat[(q+1):(2*q),((p+1):(p+q))] = sigma_SS_hat
    
    Beta.list = list()
    for (qj in 1:(2*q)) {
      if (is.na(lam_list)) outj = slim(X, t(n*Dhat), Y_rachel_column = qj,method = 'dantzig', lambda.min.ratio = min.ratio, nlambda = n.lambda) else outj = slim(X, t(n*Dhat), Y_rachel_column = qj,method = 'dantzig', lambda = lam_list)
      Beta.list[[qj]] = outj$beta
    }
    
    if (is.na(lam_list)) lam_list = outj$lambda
    
    Omegahat.list = list()
    CV = CV1 = CV2 = rep(0,length(lam_list))
    for (l in 1:length(lam_list)) {
      
      Omegahat_temp= matrix(0,2*q,p+q)
      for (qj in 1:(2*q)) {
        Omegahat_temp[qj,] = Beta.list[[qj]][,l]
      } 
      
      Omegahat.list[[l]] = Omegahat_temp
      CV1[l] = max(abs(Dhat - Omegahat.list[[l]] %*% Sigma_XX_hat))
      CV2[l] = length(which(Omegahat.list[[l]]!=0))
      
      if (tuning_method == 'aic') 
      {
        CV[l] = n * CV1[l] + 2 * CV2[l]
      } else if (tuning_method == 'bic') 
        CV[l] = n * CV1[l] + log(n) * CV2[l]
    }
    
    i_lam = which(CV == min(CV))[1]
    Omega_hat = Omegahat.list[[i_lam]]
    lam = lam_list[i_lam]
    print('lambda used:')
    print(lam)
    
    beta_part1 = kronecker(diag(2),sigma_SS_hat_inverse)%*%Omega_hat%*%lambda.k_hat 
    beta_hat = beta_part1[1:q,1] + sigma_SS_hat_inverse%*%Sigma_SG_hat%*%alpha_hat[1:p]
    alpha1_hat = beta_part1[(q+1):(2*q),1] + alpha_hat[p+1]
    total_hat = alpha1_hat + beta_hat
    
    
    Cov_part1 = sigma1_hat^2*kronecker(diag(2),sigma_SS_hat_inverse)%*%Omega_hat%*%Sigma_XX_hat%*%t(Omega_hat)%*%kronecker(diag(2),sigma_SS_hat_inverse)
    Sigma_11 = Cov_part1[1:q,1:q] + sigma2_hat^2*sigma_SS_hat_inverse
    Sigma_12 = Cov_part1[(q+1):(2*q),1:q]
    Sigma_22 = Cov_part1[(q+1):(2*q),(q+1):(2*q)]
    
    sigma_beta_hat = Sigma_11
    sigma_alpha1_hat = Sigma_22
    
    if (q > 1) {
      teststat_beta = beta_hat/sqrt(diag (sigma_beta_hat) /n)
      teststat_alpha1 = alpha1_hat/sqrt( diag (sigma_alpha1_hat) /n)
    } else if (q == 1) {
      teststat_beta = beta_hat/sqrt(sigma_beta_hat /n)
      teststat_alpha1 = alpha1_hat/sqrt( sigma_alpha1_hat/n)
    }
    
    for (q_i in 1:q) if (alpha1_hat[q_i] == 0) teststat_alpha1[q_i] = 0
    for (q_i in 1:q) if (beta_hat[q_i] == 0) teststat_beta[q_i] = 0
    
    p_beta = 2*(1-pnorm(abs(teststat_beta)))
    p_alpha1 = 2*(1-pnorm(abs(teststat_alpha1)))
    
    infer_out = list()
    infer_out$beta_hat = beta_hat
    infer_out$alpha1_hat = alpha1_hat
    infer_out$pvalue_beta_hat = p_beta
    #infer_out$pvalue_alpha1_hat = p_alpha1
    
    
    
  } else if (mediation_setting == 'complete') {
    
    sigma_SS_hat = t(S)%*%S/n
    Sigma_SG_hat = t(S)%*%G/n
    Sigma_GG_hat = t(G)%*%G/n
    sigma_hat = summary(lm(Y~S))$sigma
    
    result_scalreg = scalreg(G,Y)
    alpha_hat = result_scalreg$co
    sigma1_hat = result_scalreg$hsigma
    if(sigma1_hat > 10) {
      print('scalreg not converge at first')
      result_scalreg = scalreg(round(G,2),round(Y,2))
      sigma1_hat = result_scalreg$hsigma
    }
    
    sigma2_hat = sqrt(max(sigma_hat^2-sigma1_hat^2,0))
    lambda.k_hat = t(G)%*%(Y-G%*%alpha_hat)/n
    
    Beta.list = list()
    for (qj in 1:q) {
      if (is.na(lam_list)) outj = slim(G, t(G)%*%S, Y_rachel_column = qj,method = 'dantzig', lambda.min.ratio = min.ratio, nlambda = n.lambda) else outj = slim(G, t(G)%*%S, Y_rachel_column = qj,method = 'dantzig', lambda = lam_list)
      Beta.list[[qj]] = outj$beta
    }
    
    if (is.na(lam_list)) lam_list = outj$lambda
    
    Omegahat.list = list()
    CV = CV1 = CV2 = rep(0,length(lam_list))
    for (l in 1:length(lam_list)) {
      
      Omegahat_temp= matrix(0,q,p)
      for (qj in 1:q) {
        Omegahat_temp[qj,] = Beta.list[[qj]][,l]
      } 
      
      Omegahat.list[[l]] = Omegahat_temp
      CV1[l] = max(abs(Sigma_SG_hat - Omegahat.list[[l]] %*% Sigma_GG_hat))
      CV2[l] = length(which(Omegahat.list[[l]]!=0))
      
      if (tuning_method == 'aic') 
      {
        CV[l] = n * CV1[l] + 2 * CV2[l]
      } else if (tuning_method == 'bic') 
        CV[l] = n * CV1[l] + log(n) * CV2[l]
    }
    
    i_lam = which(CV == min(CV))[1]
    Omega_hat = Omegahat.list[[i_lam]]
    lam = lam_list[i_lam]
    print('lambda used:')
    print(lam)
    
    beta_hat = solve(sigma_SS_hat)%*%(Sigma_SG_hat%*%alpha_hat+Omega_hat%*%lambda.k_hat)
    sigma_beta_hat = sigma1_hat^2*solve(sigma_SS_hat)%*%Omega_hat%*%Sigma_GG_hat%*%t(Omega_hat)%*%solve(sigma_SS_hat) + sigma2_hat^2*solve(sigma_SS_hat)
    if (q >1) teststat = beta_hat/sqrt(diag (sigma_beta_hat)/n) else if (q==1) teststat = beta_hat/sqrt(sigma_beta_hat/n)
    
    p_beta = 2*(1-pnorm(abs(teststat)))
    
    infer_out = list()
    infer_out$beta_hat = beta_hat
    infer_out$pvalue_beta_hat = p_beta
  }
  
  return(infer_out)
  
}
