% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fit_and_reporting.R
\name{loadings.MxModel}
\alias{loadings.MxModel}
\title{Extract factor loadings from an EFA (factor analysis).}
\usage{
\method{loadings}{MxModel}(x, ...)
}
\arguments{
\item{x}{A RAM model from which to get loadings.}

\item{...}{Other parameters (currently unused)}
}
\value{
\itemize{
\item loadings matrix
}
}
\description{
loadings extracts the factor loadings from an EFA (factor analysis) model.
It behaves equivalently to stats::loadings, returning the loadings from an
EFA (factor analysis). However it does not store the rotation matrix.
}
\examples{
myVars <- c("mpg", "disp", "hp", "wt", "qsec")
m1 = umxEFA(name = "test", factors = 2, data = mtcars[, myVars])
loadings(m1)

}
\references{
\itemize{
\item \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
}
}
\seealso{
\itemize{
\item \code{\link[=factanal]{factanal()}}, \code{\link[=loadings]{loadings()}}
}

Other Miscellaneous Functions: 
\code{\link{deg2rad}()},
\code{\link{fin_interest}()},
\code{\link{fin_percent}()},
\code{\link{fin_valuation}()},
\code{\link{rad2deg}()},
\code{\link{umxBrownie}()}
}
\concept{Miscellaneous Functions}
