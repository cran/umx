% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/datasets.R
\docType{data}
\name{us_skinfold_data}
\alias{us_skinfold_data}
\title{Anthropometric data on twins}
\format{
A data frame with 53940 twin families (1 per row) each twin measured on 10 variables.
}
\usage{
data(us_skinfold_data)
}
\description{
A dataset containing height, weight, BMI, and skin-fold fat measures in several
hundred US twin families participating in the MCV Cardiovascular Twin Study (PI Schieken).
Biceps and Triceps are folds above and below the upper arm (holding arm palm upward),
Calf (fold on the calf muscle), Subscapular (fold over the shoulder blade),
Suprailiacal (fold between the hip and ribs).
}
\details{
\itemize{
\item \emph{fan} FamilyID (t1=male,t2=female)
\item \emph{zyg} Zygosity  1:mzm, 2:mzf, 3:dzm, 4:dzf, 5:dzo
\item \emph{ht_T1}  Height of twin 1 (cm)
\item \emph{wt_T1}  Weight of twin 1 (kg)
\item \emph{bmi_T1} BMI of twin 1
\item \emph{bml_T1} log BMI of twin 1
\item \emph{bic_T1} Biceps Skinfold of twin 1
\item \emph{caf_T1} Calf Skinfold of twin 1
\item \emph{ssc_T1} Subscapular Skinfold of twin 1
\item \emph{sil_T1} Suprailiacal Skinfold of twin 1
\item \emph{tri_T1} Triceps Skinfold of twin 1
\item \emph{ht_T2}  Height of twin 2
\item \emph{wt_T2}  Weight of twin 2
\item \emph{bmi_T2} BMI of twin 2
\item \emph{bml_T2} log BMI of twin 2
\item \emph{bic_T2} Biceps Skinfold of twin 2
\item \emph{caf_T2} Calf Skinfold of twin 2
\item \emph{ssc_T2} Subscapular Skinfold of twin 2
\item \emph{sil_T2} Suprailiacal Skinfold of twin 2
\item \emph{tri_T2} Triceps Skinfold of twin 2
}
}
\examples{
\dontrun{
data(us_skinfold_data)
str(us_skinfold_data)
par(mfrow = c(1, 2))  # 1 rows and 3 columns
plot(ht_T1 ~ht_T2, ylim = c(130, 165), data = subset(us_skinfold_data, zyg == 1))
plot(ht_T1 ~ht_T2, ylim = c(130, 165), data = subset(us_skinfold_data, zyg == 3))
par(mfrow = c(1, 1))  # back to as it was
}
}
\references{
Moskowitz, W. B., Schwartz, P. F., & Schieken, R. M. (1999).
Childhood passive smoking, race, and coronary artery disease risk:
the MCV Twin Study. Medical College of Virginia.
\emph{Archives of Pediatrics and Adolescent Medicine}, \strong{153}, 446-453.
\url{https://pubmed.ncbi.nlm.nih.gov/10323623/}
}
\seealso{
Other datasets: 
\code{\link{Fischbein_wt}},
\code{\link{GFF}},
\code{\link{docData}},
\code{\link{iqdat}},
\code{\link{umx}}
}
\concept{datasets}
\keyword{datasets}
