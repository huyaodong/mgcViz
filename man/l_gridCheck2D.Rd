% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/L_gridCheck2D.R
\name{l_gridCheck2D}
\alias{l_gridCheck2D}
\title{Binning and checking GAM residuals}
\usage{
l_gridCheck2D(gridFun = mean, bw = c(NA, NA), stand = TRUE, binFun = NULL, ...)
}
\arguments{
\item{gridFun}{scalar-valued function used to summarize the residuals in each bin.}

\item{bw}{numeric vector giving bin width in the vertical and horizontal directions. See the \code{binwidth}
arguments in \code{?ggplot2::stat_summary_hex}. If left to \code{NA}, it will be set to 1/20
of the ranges of x1 and x2.}

\item{stand}{if left to \code{TRUE} then the observed statistic in the i-th cell is normalized using
the simulated statistics in that same cell. That is, we will actually plot
\code{std_stat = (obs_stat-mean(sim_stat))/sd(sim_stat)}.}

\item{binFun}{the \code{ggplot2} function used to perform the binning. By default it
is either \link[ggplot2:stat_summary_2d]{ggplot2::stat_summary_2d} or \link[ggplot2:stat_summary_hex]{ggplot2::stat_summary_hex}, depending
on the class of the covariates x1 and x2.}

\item{...}{graphical arguments to be passed to \code{ggplot2::stat_summary_hex}.}
}
\value{
An object of class \code{gamLayer}
}
\description{
This layer bins the residuals, r, according to the value of the corresponding
covariates, x1 and x2. Then the residuals in each bin are summarized using a
scalar-valued statistic. Confidence intervals for the statistic corresponding
to each bin can be obtained by simulating residuals from the fitted GAM
model, which are then binned and summarized. Mainly useful in conjuction with \link{check2D}.
}
\examples{
library(mgcViz);
set.seed(4124)
n <- 1e4
x <- rnorm(n); y <- rnorm(n);

# Residuals are heteroscedastic w.r.t. x
ob <- (x)^2 + (y)^2 + (1*abs(x) + 1)  * rnorm(n)
b <- bam(ob ~ s(x,k=30) + s(y, k=30), discrete = TRUE)
b <- getViz(b, nsim = 50)

# Don't see much by looking at mean
check2D(b, "x", "y") + l_gridCheck2D(gridFun = mean, bw = c(0.4, 0.4))

# Variance pattern along x-axis clearer now
check2D(b, "x", "y") + l_gridCheck2D(gridFun = sd, bw = c(0.4, 0.4))
 
}
