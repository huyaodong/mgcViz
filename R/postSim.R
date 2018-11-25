#'
#' Posterior simulation from a GAM object
#' 
#' @description This method can be used to simulate vectors of responses from the 
#'              Gaussian posterior approximation of a gamObject.
#' @param o the output of a \code{gam()} or \code{bam()} call.
#' @param nsim the number of simulated vectors of responses. A positive integer.
#' @param newdata Optional new data frame used to perform the simulations. To be passed to \link{predict.gam}.
#' @param fun function used to summarize each vector of simulated responses. It must take a vector as argument, 
#'            but it can output any type of object.
#' @param method the method used for the simulation of responses. See \link{simulate.gam}.
#' @param w vector of prior weights of each response. See \link{simulate.gam}. 
#' @param offset numeric vector of offsets. For GAMs with multiple linear predictor (see eg \link{gaulss}) it
#'               must be a list of vectors. If \code{newdat!=NULL} the offsets will be assumed to be zero, 
#'               unless their are explicitly provided. If \code{newdat==NULL} the simulations will use the 
#'               offsets used during model fitting, unless offset is explicitly provided. 
#' @param simplify character string indicating the function that will be used to simplify the list of simulations.
#'                 It will be used in a call such as \code{do.call(simplify, listOfSimul)}. Set it to \code{NULL} to get
#'                 simply a list out.
#' @param ... arguments to be passed to \link{vcov.gam}.
#' @return A matrix where each row is a vector of simulated responses or a transformed version of it. 
#'         
#' @examples 
#' library(mgcViz)
#' library(MASS)
#' b <- gam(accel~s(times, k=20), data=mcycle)
#' 
#' # Simulate list of 10 vectors of responses from posterior
#' n <- 10
#' sim <- postSim(o = b, nsim = n)
#' 
#' # Posterior simulations in grey and data in red
#' plot(rep(mcycle$times, n), as.vector(t(sim)), col = "grey", 
#'      ylab = "Acceleration", xlab = "Times")
#' points(mcycle$times, mcycle$accel, col = 2)
#' 
#' # There is clear disagreement between simulations' and data's 
#' # conditional variance, which can be solved using flexible GAMLSS model:
#' b <- gam(list(accel~s(times, k=20), ~s(times)), data=mcycle, family = gaulss)
#' sim <- postSim(o = b, nsim = n)
#' plot(rep(mcycle$times, n), as.vector(t(sim)), col = "grey", 
#'      ylab = "Acceleration", xlab = "Times")
#' points(mcycle$times, mcycle$accel, col = 2)
#' 
#' @importFrom plyr rlply laply
#' @importFrom mgcv rmvn
#' @importFrom stats coef vcov
#' @export postSim
#' 
postSim <- function(o, nsim, newdata, fun = identity, method = "auto", 
                    w = NULL, offset = NULL, simplify = "rbind", ...)
{
  if( is.null(o$sig2) ){ o$sig2 <- summary(o)$dispersion }
  
  # Get mean linear predictor
  muHat <- predict(o, type = "link", newdata = newdata)
  X <- predict(o, type = "lpmatrix", newdata = newdata)
  n <- nrow( as.matrix(muHat) )
  
  # Get coefficients and their covariance matrix
  cf <- coef(o) 
  V <- vcov(o, ...)
  
  if( is.null(w)  ){
    if( missing(newdata) ){ w <- o$prior.weights } else { w <- rep(1, n) }
  } 
  
  # Get inverse link and determine offsets
  if( is.null(attr(X, "lpi")) ){ # Single linear predictor case
    out <- .postSim1LP(o = o, X = X, cf = cf, V = V, n = n, muHat = muHat, 
                       nsim = nsim, w = w, method = method, fun = fun, offset = offset, newdata = newdata)
  } else { # Multiple linear predictor case
    out <- .postSimMLP(o = o, X = X, cf = cf, V = V, n = n, muHat = muHat, 
                       nsim = nsim, w = w, method = method, fun = fun, offset = offset, newdata = newdata)
  }
  
  # Try to simplify, if this fails return the list as it is
  if( !is.null(simplify) ){
   out <- tryCatch( do.call(simplify, out), error = function(e) out )
  }
  
  return( out )
  
}


######### Internal function for single linear predictor case
#
.postSim1LP <- function(o, X, cf, V, n, muHat, nsim, w, method, fun, offset, newdata){
  
  lnki <- o$family$linkinv   # Get inverse link function
  
  # Deal with the offset
  if( !is.null(offset) ){ # User provided offset: nothing to do
    offI <- offset
  } else { 
    offI <- numeric( n )                # Default offset is zero
    if( !is.null(attr(X, "model.offset")) ){  # Original fit included offset
      if( missing(newdata) ){                 # We re-calculate it using original data
        offset <- muHat - drop(X %*% cf)
      } else {                                # If we are using new data we need the user
        message("NB no offset provided")      # to provide the offset
      }
    }
  }
  
  # Simulate a vector of responses for each vector of coefficients, and transform it using fun()
  out <- rlply(nsim,
               {
                 beta <- rmvn(1, cf, V)
                 mu <- lnki( X %*% beta + offI )
                 # Simulated and transform
                 fun( drop(.simulate.gam(mu = mu, w = w, sig = o$sig2, method = method, fam = o$family, nsim = 1, u = NULL)) )
               })
  
  return( out )
  
}


######### Internal function for multiple linear predictors case
#
.postSimMLP <- function(o, X, cf, V, n, muHat, nsim, w, method, fun, offset, newdata){
  
  lpi <- attr(X, "lpi")
  nte <- length(lpi)                                 
  lnki <- lapply(o$family$linfo, "[[", "linkinv")  # Get inverse link function
  
  # Deal with the offset
  if( !is.null(offset) ){ # User provided offset: nothing to do
    offI <- offset
  } else { 
    offI <- rlply(nte, { numeric(n) })  # Default offset is zero
    if( !is.null(attr(X, "model.offset")) ){  # Original fit included offset
      if( missing(newdata) ){                 # We re-calculate it for each term using original data
        offset <- lapply(1:nte, 
                         function(.ii){
                           drop(muHat[ , .ii] - X[ , lpi[[.ii]]] %*% cf[lpi[[.ii]]])
                         })
      } else {                                # If we are using new data we need the user
        message("NB no offset provided")      # to provide the offset
      }
    }
  }
  
  # Simulate a vector of responses for each vector of coefficients, and transform it using fun()
  out <- rlply(nsim,  
               {
                 beta <- rmvn(1, cf, V)
                 mu <- t( laply(1:nte, # Need to do it term by term
                                function(.ii){
                                  lnki[[.ii]]( X[ , lpi[[.ii]]] %*% beta[lpi[[.ii]]] + offI[[.ii]] )
                                }) )
                 # Simulated and transform
                 fun( drop(.simulate.gam(mu = mu, w = w, sig = o$sig2, method = method, fam = o$family, nsim = 1, u = NULL)) )
               })
  
}
