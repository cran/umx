# system("mdimport ~/bin/umx/R")
#
#   Copyright 2007-2018 Timothy C. Bates
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
# 
#        https://www.apache.org/licenses/LICENSE-2.0
# 
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# =====================
# = Model Diagnostics =
# =====================

#' Diagnose problems in a model - this is a work in progress.
#'
#' The goal of this function is to diagnose problems in a model and return suggestions to the user.
#' It is a work in progress, and probably is not of any use as yet.
#'
#' @param model an \code{\link{mxModel}} to diagnose
#' @param tryHard whether I should try and fix it? (defaults to FALSE)
#' @param diagonalizeExpCov Whether to diagonalize the ExpCov
#' @return - helpful messages and perhaps a modified model
#' @export
#' @family Teaching and Testing functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' myData = mxData(cov(demoOneFactor), type = "cov", numObs = 500)
#' m1 <- umxRAM("OneFactor", data = myData,
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' m1 = mxRun(m1)
#' umxSummary(m1, show = "std")
#' umxDiagnose(m1)
umxDiagnose <- function(model, tryHard = FALSE, diagonalizeExpCov = FALSE){
	# 1. First thing to check is whether the covariance matrix is positive definite.
	minEigen = min(eigen(umxExpCov(model))$values)
	if(minEigen<0){
		message("The expected covariance matrix is not positive definite")
		# now what?
	}
  # Best diagnostics are
  # 1. observed data variances and means
  # 2. expected variances and means
  # 3 Difference of these?
  # try
  # diagonalizeExpCov diagonal.
  # umx_any_ordinal()
  # more tricky - we should really report the variances and the standardized thresholds.
  # The guidance would be to try starting with unit variances and thresholds that are within +/- 2SD of the mean.
  # [bivariate outliers %p](https://openmx.ssri.psu.edu/thread/3899)
}

# =============================
# = Fit and Reporting Helpers =
# =============================

#' AIC weight-based conditional probabilities.
#'
#' @description
#' Returns the best model by AIC, and computes the probabilities 
#' according to AIC weight-based conditional probabilities (Wagenmakers & Farrell, 2004). 
#'
#' @param models a list of models to compare.
#' @param digits (default 2)
#' @return - Best model
#' @export
#' @family Reporting Functions
#' @seealso - \code{\link{AIC}}
#' @references - Wagenmakers E.J., Farrell S. (2004), 192-196. AIC model selection using Akaike weights. *Psychonomic Bulletin and Review*. **11**, 192-196. \url{https://www.ncbi.nlm.nih.gov/pubmed/15117008}
#' @examples
#' l1 = lm(mpg~ wt + disp, data=mtcars)
#' l2 = lm(mpg~ wt, data=mtcars)
#' umxWeightedAIC(models = list(l1, l2))
umxWeightedAIC <- function(models, digits= 2) {
	if(class(models[[1]])== "numeric"){
		stop("Please input the list of models to compare as a list, i.e. models = list(model1, model2)")
	}
	AIClist = c()
	for (i in models) {
		AIClist = c(AIClist, AIC(i))
	}
	whichBest = which.min(AIClist)
	bestModel = models[[whichBest]]
	aic.weights = round(MuMIn::Weights(AIClist), 2)
	if(isS4(models[[1]]) & is(models[[1]], "MxModel")){
		# TODO: this should work with  umx_is_MxModel(models[[1]])
		message("The ", omxQuotes(bestModel$name), " model is the best fitting model according to AIC.")
		# Probabilities according to AIC Weights (Wagenmakers et al https://www.ncbi.nlm.nih.gov/pubmed/15117008 )
		message("AIC weight-based conditional probabilities {Wagenmakers, 2004, 192-196} of being the best model for ", 
			omxQuotes(namez(models)), " respectively are: ",
			omxQuotes(aic.weights), " Using MuMIn::Weights(AIC()).")		
	}else{
		if("call" %in% names(bestModel)){
			# ID = paste0("Model ", omxQuotes(bestModel$call))
			ID = paste0("Model ", whichBest)
		} else {
			ID = paste0("Model ", whichBest)
		}
		message(ID, " is the best fitting model according to AIC.")
		message("AIC weight-based conditional probabilities {Wagenmakers, 2004, 192-196} of being the best model are (for each model you gave me): ",
			omxQuotes(aic.weights), " Using MuMIn::Weights(AIC()).")		
		
	}
	invisible(bestModel)
}

#' Reduce models, and report the results.
#'
#' @description
#' Given a `umx` model (currently `umxACE` and `umxGxE` are supported - ask for more!)
#' `umxReduce` will conduct a formalised reduction process.
#'
#' **GxE model reduction**
#' For \code{\link{umxGxE}} models, each form of moderation is tested
#' on its own, and jointly.
#' Also, C is removed, and moderation tested in this model.
#' 
#' **ACE model reduction**
#' For \code{\link{umxACE}} models, A and then C are removed and tested.
#' 
#' It reports the results in a table. Set the format of the table with
#' \code{\link{umx_set_table_format}}()., or set `report` to "html" to open a
#' table for pasting into a word processor.
#' 
#' `umxReduce` is a work in progress, with more automatic reductions coming as demand emerges.
#' I am thinking for RAM models to drop NS paths, and report that test.
#'
#' @param model The \code{\link{mxModel}} which will be reduced.
#' @param report How to report the results. "html" = open in browser
#' @param baseFileName (optional) custom filename for html output (defaults to "tmp")
#' @param ... Other parameters to control model summary
#' @family Reporting Functions
#' @family Twin Reporting Functions
#' @seealso \code{\link{umxReduceGxE}}, \code{\link{umxReduceACE}}
#' @references - Wagenmakers, E.J., & Farrell, S. (2004). AIC model selection using Akaike weights. *Psychonomic Bulletin and Review*, **11**, 192-196. [doi:](https://doi.org/10.3758/BF03206482)
#' @export
#' @md
umxReduce <- function(model, report = c("markdown", "inline", "html", "report"), baseFileName = "tmp", ...){
	UseMethod("umxReduce", model)
}

#' @export
umxReduce.default <- function(model, ...){
	stop("umxReduce is not defined for objects of class:", class(model))
}

#' Reduce a GxE model.
#'
#' @description
#' This function can perform model reduction for [umxGxE][umxGxE], 
#' testing dropping means-moderation, a`,c` & e`, as well as c & c`, a & a` etc.
#'
#' It reports the results in a table. Set the format of the table with
#' [umx_set_table_format]. Or set `report` to "html" to open a
#' table for pasting into a word processor.
#' 
#' @param model An \code{\link{mxModel}} to reduce.
#' @param report How to report the results. "html" = open in browser.
#' @param baseFileName (optional) custom filename for html output (defaults to "tmp").
#' @param ... Other parameters to control model summary.
#' @return best model
#' @export
#' @family Twin Reporting Functions
#' @seealso \code{\link{umxReduceACE}}, \code{\link{umxReduce}}
#' @references - Wagenmakers, E.J., & Farrell, S. (2004). AIC model selection using Akaike weights.
#' *Psychonomic Bulletin and Review*, **11**, 192-196. [doi:](https://doi.org/10.3758/BF03206482).
#' @md
#' @examples
#' \dontrun{
#' model = umxReduce(model)
#' }
umxReduceGxE <- function(model, report = c("markdown", "inline", "html", "report"), baseFileName = "tmp_gxe", ...) {
	umx_is_MxModel(model)
	report = match.arg(report)
	if(class(model) == "MxModelGxE"){		
		# Reduce GxE Model
		# Good to drop the means if possible? I think not. Better to model their most likely value, not lock it to zerp
		no_lin_mean = umxModify(model, update = "lin11" , name = "No_lin_mean" )
		no_sq_mean  = umxModify(model, update = "quad11" , name = "No_quad_mean")
		nomeans     = umxModify(model, regex = "lin|quad", name = "No_means_moderation")

		noAmod       = umxModify(model, update = "am_r1c1", name = "No_mod_on_A")
		noCmod       = umxModify(model, update = "cm_r1c1", name = "No_mod_on_C")
		noEmod       = umxModify(model, update = "em_r1c1", name = "No_mod_on_E")

		noACEmod     = umxModify(model, regex  = "[ace]m" , name = "No_moderation")

		no_a_no_am  = umxModify(noAmod , update = "a_r1c1", name = "No_A_no_mod_on_A")
		no_c_no_cm  = umxModify(noCmod , update = "c_r1c1", name = "No_C_no_mod_on_C")
		no_c_no_cem = umxModify(no_c_no_cm, update = "em_r1c1", name = "No_c_no_ce_mod")

		no_c_no_mod = umxModify(no_c_no_cem, update = "am_r1c1", name = "No_c_no_moderation")

		comparisons = c(
			no_lin_mean, no_sq_mean, nomeans, 
			noAmod, noCmod, noEmod, noACEmod,
			no_a_no_am, no_c_no_cm, no_c_no_cem,
			no_c_no_mod
		)

		# ====================
		# = everything table =
		# ====================
		
		umxCompare(model, comparisons, all = TRUE, report = report, file = paste0(baseFileName, "1.html"))
		# umxCompare(no_c_no_cem, no_c_no_moderation, all = TRUE, report = report, file = paste0(baseFileName, "2.html"))
		modelList = c(model, comparisons)
		
		# get list of AICs
		AIClist = c()
		for (i in modelList) {
			AIClist = c(AIClist, AIC(i))
		}
		whichBest = which.min(AIClist)
		bestModel = modelList[[whichBest]]
		message("The ", omxQuotes(bestModel$name), " model is the best fitting model according to AIC.")
		# Probabilities according to AIC MuMIn::Weights (Wagenmakers et al https://www.ncbi.nlm.nih.gov/pubmed/15117008 )
		aic.weights = round(Weights(AIClist), 2)
		message("AIC weight-based conditional probabilities {Wagenmakers, 2004, 192-196} of being the best model for ", 
			omxQuotes(namez(modelList)), " respectively are: ",
			omxQuotes(aic.weights), " Using MuMIn::Weights(AIC())."
		)
		invisible(bestModel)
	} else {
		stop("This function is for GxE. Feel free to let me know what you want...")
	}
}
#' @export
umxReduce.MxModelGxE <- umxReduceGxE

#' Reduce an ACE model.
#'
#' This function can perform model reduction on \code{\link{umxACE}} models,
#' testing dropping A and C, as well as an ADE or ACE model, displaying the results
#' in a table, and returning the best model.
#'
#' It is designed for testing univariate models. You can offer up either the ACE or ADE base model.
#'
#' Suggestions for more sophisticated automation welcomed!
#'
#' @param model an ACE or ADE \code{\link{mxModel}} to reduce
#' @param report How to report the results. "html" = open in browser
#' @param baseFileName (optional) custom filename for html output (defaults to "tmp")
#' @param intervals Recompute CIs (if any included) on the best model (default = TRUE)
#' @param ... Other parameters to control model summary
#' @return Best fitting model
#' @export
#' @family Twin Reporting Functions
#' @seealso \code{\link{umxReduceGxE}}, \code{\link{umxReduce}}
#' @references - Wagenmakers, E.J., & Farrell, S. (2004). AIC model selection using Akaike weights. *Psychonomic Bulletin and Review*, **11**, 192-196. [doi:](https://doi.org/10.3758/BF03206482)
#' @md
#' @examples
#' data(twinData)
#' mzData <- subset(twinData, zygosity == "MZFF")
#' dzData <- subset(twinData, zygosity == "DZFF")
#' m1 = umxACE(selDVs = "bmi", dzData = dzData, mzData = mzData, sep = "")
#' m2 = umxReduce(m1)
#' umxSummary(m2)
#' m1 = umxACE(selDVs = "bmi", dzData = dzData, mzData = mzData, sep = "", dzCr = .25)
#' m2 = umxReduce(m1)
umxReduceACE <- function(model, report = c("markdown", "inline", "html", "report"), baseFileName = "tmp", intervals = TRUE, ...) {
	report = match.arg(report)
	oldAutoPlot = umx_set_auto_plot(FALSE, silent = TRUE)
	if(model$top$dzCr$values == 1){
		message("You gave me an ACE model")		
		ACE = model
		ADE = umxModify(model, 'dzCr_r1c1', value = .25, name = "ADE")
		if(-2*logLik(ACE) > -2*logLik(ADE)){
			CE = umxModify(ADE, regex = "a_r[0-9]+c[0-9]+" , name = "DE")
			AE = umxModify(ADE, regex = "c_r[0-9]+c[0-9]+" , name = "AE")
			message("A dominance model is preferred, set dzCr = 0.25")
		}else{
			CE = umxModify(ACE, regex = "a_r[0-9]+c[0-9]+" , name = "CE")
			AE = umxModify(ACE, regex = "c_r[0-9]+c[0-9]+" , name = "AE")
		}
	}else if(model$top$dzCr$values == .25){
		if(model$name=="ACE"){
			message("You gave me an ADE model, but it was called 'ACE'. I have renamed it ADE for the purposes of clarity in model reduction.")
			model = mxRename(model, newname = "ADE", oldname = "ACE")
		} else {
			message("You gave me an ADE model.")
		}
		ADE = model
		ACE = umxModify(ADE, 'dzCr_r1c1', value = 1, name = "ACE")
		AE  = umxModify(ADE, regex = "c_r[0-9]+c[0-9]+" , name = "AE")
		if(-2*logLik(ADE) > -2*logLik(ACE)){
			CE = umxModify(ACE, regex = "a_r[0-9]+c[0-9]+" , name = "CE")
			message("An ACE model is preferred, set dzCr = 1.0")
		}else{
			CE = umxModify(ADE, regex = "a_r[0-9]+c[0-9]+" , name = "DE")
		}
	}else{
		stop(model$top$dzCr$values, " is an odd number for dzCr, isn't it? I was expecting 1 (C) or .25 (D)",
		"\nPerhaps you're John Loehlin, and are doing an assortative mating test? e-mail me to get this added here.")
		# TODO umxReduceACE handle odd values of dzCr as assortative mating etc.?
		bestModel = model
	}
	# = Show fit table =
	umxCompare(ACE, c(ADE, CE, AE), all = TRUE, report = report)
	whichBest = which.min(AIC(ACE, ADE, CE, AE)[,"AIC"])[1]
	bestModel = list(ACE, ADE, CE, AE)[[whichBest]]
	message("The ", omxQuotes(bestModel$name), " model is the best fitting model according to AIC.")
	# Probabilities according to AIC MuMIn::Weights (Wagenmakers et al https://www.ncbi.nlm.nih.gov/pubmed/15117008 )
	aic.weights = round(Weights(AIC(ACE, ADE, CE, AE)[,"AIC"]), 2)
	message("AIC weight-based {Wagenmakers, 2004, 192-196} conditional probabilities of being the best model for ", 
		omxQuotes(namez(c(ACE, ADE, CE, AE))), " respectively are: ", 
		omxQuotes(aic.weights), " Using MuMIn::Weights(AIC()).")

	if(intervals){
		bestModel = mxRun(bestModel, intervals = intervals)
	}
	umx_set_auto_plot(oldAutoPlot, silent = TRUE)
	invisible(bestModel)
}
#' @export
umxReduce.MxModelACE <- umxReduceACE

#' Get residuals from an MxModel
#'
#' Return the \code{\link{residuals}} from an OpenMx RAM model. You can format these (with digits), and suppress small values.
#'
#' @rdname residuals.MxModel
#' @param object An fitted \code{\link{mxModel}} from which to get residuals
#' @param digits round to how many digits (default = 2)
#' @param suppress smallest deviation to print out (default = NULL = show all)
#' @param ... Optional parameters
#' @return - matrix of residuals
#' @export
#' @family Reporting functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("g")
#' manifests = names(demoOneFactor)
#' m1 <- mxModel("One Factor", type = "RAM", 
#' 	manifestVars = manifests, latentVars = latents, 
#' 	mxPath(from = latents, to = manifests),
#' 	mxPath(from = manifests, arrows = 2),
#' 	mxPath(from = latents, arrows = 2, free = FALSE, values = 1.0),
#' 	mxData(cov(demoOneFactor), type = "cov", numObs = 500)
#' )
#' m1 = umxRun(m1, setLabels = TRUE, setValues = TRUE)
#' residuals(m1)
#' residuals(m1, digits = 3)
#' residuals(m1, digits = 3, suppress = .005)
#' # residuals are returned as an invisible object you can capture in a variable
#' a = residuals(m1); a
residuals.MxModel <- function(object, digits = 2, suppress = NULL, ...){
	umx_check_model(object, type = NULL, hasData = TRUE)
	expCov = umxExpCov(object, latents = FALSE)
	if(object$data$type == "raw"){
		obsCov = umxHetCor(object$data$observed)
	} else {
		obsCov = object$data$observed
	}
	resid = cov2cor(obsCov) - cov2cor(expCov)
	umx_print(data.frame(resid), digits = digits, zero.print = ".", suppress = suppress)
	if(is.null(suppress)){
		print("nb: You can zoom in on bad values with, e.g. suppress = .01, which will hide values smaller than this. Use digits = to round")
	}
	invisible(resid)
}

# define generic loadings...
#' loadings
#' Generic loadings function to extract factor loadings from exploratory or confirmatory
#' factor analyses.
#'
#' See \code{\link[umx]{loadings.MxModel}} to access the loadings of OpenMx EFA models.
#' 
#' Base \code{\link[stats]{loadings}} handles \code{\link{factanal}} objects. 
#'
#' @param x an object from which to get loadings 
#' @param ... additional parameters
#' @return - matrix of loadings
#' @export
#' @family Reporting functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
loadings <- function(x, ...) UseMethod("loadings")
#' @export
loadings.default <- function(x, ...) stats::loadings(x, ...) 

# TODO: alternative approach would be to use setGeneric("loadings")

#' Extract factor loadings from an EFA (factor analysis).
#'
#' loadings extracts the factor loadings from an EFA (factor analysis) model.
#' It behaves equivalently to stats::loadings, returning the loadings from an 
#' EFA (factor analysis). However it does not store the rotation matrix.
#'
#' @param x A RAM model from which to get loadings.
#' @param ... Other parameters (currently unused)
#' @return - loadings matrix
#' @export
#' @family Reporting Functions
#' @seealso - \code{\link{factanal}}, \code{\link{loadings}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' myVars <- c("mpg", "disp", "hp", "wt", "qsec")
#' m1 = umxEFA(name = "test", factors = 2, data = mtcars[, myVars])
#' loadings(m1)
loadings.MxModel <- function(x, ...) {
	x$A$values[x@manifestVars, x@latentVars, drop = FALSE]
}


#' Get confidence intervals from a umx model
#'
#' Implements confidence interval function for umx models.
#' 
#' Note: By default, requesting new CIs wipes the existing ones.
#' To keep these, set wipeExistingRequests = FALSE.
#'
#' @details *Note*: \code{\link{confint}} is an OpenMx function which will return SE-based CIs.
#' 
#' Because these can take time to run, by default only CIs already computed will be reported. Set run = TRUE to run new CIs.
#' If parm is empty, and run = FALSE, a message will alert you to add run = TRUE. 
#'
#' @param object An \code{\link{mxModel}}, possibly already containing \code{\link{mxCI}}s that have been \code{\link{mxRun}} with intervals = TRUE))
#' @param parm	Which parameters to get confidence intervals. Can be "existing", "smart", "all", or a vector of names.
#' @param level	The confidence level required (default = .95)
#' @param run Whether to run the model (defaults to FALSE)
#' @param wipeExistingRequests Whether to remove existing CIs when adding new ones (ignored if parm = 'existing').
#' @param optimizer defaults to "SLSQP". Might try "NelderMead"
#' @param showErrorCodes (default = FALSE)
#' @param ... Additional argument(s) for umxConfint.
#' @export
#' @return - \code{\link{mxModel}}
#' @family Reporting functions
#' @seealso - \code{\link[stats]{confint}}, \code{\link{umxCI}} 
#' @references - \url{https://www.github.com/tbates/umx}
#' @md
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(from = latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' 
#' m1 = umxConfint(m1, run = TRUE) # There are no existing CI requests...
#' 
#' # Add a CI request for "G_to_x1", run, and report. Save with this CI computed
#' m2 = umxConfint(m1, parm = "G_to_x1", run = TRUE) 
#' 
#' # Just print out any existing CIs
#' umxConfint(m2) 
#' 
#' # CI requests added for free matrix parameters. User prompted to set run = TRUE
#' m3 = umxConfint(m1, "all")
#' 
#' # Run the requested CIs
#' m3 = umxConfint(m3, run = TRUE) 
#' 
#' # Run CIs for free one-headed (asymmetric) paths in RAM model. 
#' #   note: Deletes other existing requests,
#' tmp = umxConfint(m1, parm = "A", run = TRUE)
#' 
#' # Wipe existing CIs, add G_to_x1
#' tmp = umxConfint(m1, parm = "G_to_x1", run = TRUE, wipeExistingRequests = TRUE) 
#' 
#' \dontrun{
#' # For complex twin models, where algebras have parameters in some cells, smart might help
#' # note: only implemented for umxCP so far
#' m2 =  umxConfint(m1, "smart")
#' }
#'
umxConfint <- function(object, parm = c("existing", "smart", "all", "or one or more labels"), wipeExistingRequests = TRUE, level = 0.95, run = FALSE, showErrorCodes = FALSE, optimizer= c("current", "SLSQP")) {
	optimizer = match.arg(optimizer)
	if(optimizer=="current"){
		optimizer = umx_set_optimizer(silent=TRUE)
	}
	parm = umx_default_option(parm, c("existing", "smart", "all", "or one or more labels"), check = FALSE)
	# 1. remove existing CIs if requested to
	if(wipeExistingRequests && (parm != "existing")){
		if(length(object$intervals)){
			object = mxModel(object, remove = TRUE, object$intervals)
			message("Removed existing CIs")
			# TODO rationalise umxConfint and umxCI (priority!)
			# object = umxCI(object, which = "ALL", remove=TRUE)
		}
	}
	# 1. Add CIs if requested
	if (length(parm) >1){
		# Add requested CIs to model
		# TODO umxConfint: Check that these are valid and not duplicates
		object = mxModel(object, mxCI(parm, interval = level))
	} else if (parm == "all") {
		CIs_to_set = names(omxGetParameters(object, free = TRUE))
		object = mxModel(object, mxCI(CIs_to_set, interval = level))
	} else if (parm == "smart"){
		if(class(object) == "MxModelCP"){
			# Add individual smart (only free cell) mxCI requests
			# For CP model, these are the free cells in
			# 	top.as_std, top.cs_std, top.es_std
			# object = m1
			this = object$top$as$free
			template = umxMatrix("A", "Full", dim(this)[1], dim(this)[2])$labels
			patt = "^.*_r([0-9]+)c([0-9]+)$"
			as_free = gsub(pattern = patt, replacement= "top.as_std[\\1,\\2]", template)[which(object$top$as$free)]
			cs_free = gsub(pattern = patt, replacement= "top.cs_std[\\1,\\2]", template)[which(object$top$cs$free)]
			es_free = gsub(pattern = patt, replacement= "top.es_std[\\1,\\2]", template)[which(object$top$es$free)]

			# Get labels for free cells in top.cp_loadings_std
			this = object$top$cp_loadings$free
			template = umxMatrix("A", "Full", dim(this)[1], dim(this)[2])$labels
			cp_loadings_free = gsub(pattern = patt, replacement= "top.cp_loadings_std[\\1,\\2]", template)[which(this)]

			# top.a_cp, top.c_cp, top.e_cp
			this = object$top$a_cp$free
			template  = umxMatrix("A", "Full", dim(this)[1], dim(this)[2])$labels
			a_cp_free = gsub(pattern = patt, replacement= "top.a_cp[\\1,\\2]", template)[which(object$top$a_cp$free)]
			c_cp_free = gsub(pattern = patt, replacement= "top.c_cp[\\1,\\2]", template)[which(object$top$c_cp$free)]
			e_cp_free = gsub(pattern = patt, replacement= "top.e_cp[\\1,\\2]", template)[which(object$top$e_cp$free)]

			CIs2Add = c(a_cp_free, c_cp_free, e_cp_free, cp_loadings_free, as_free, cs_free, es_free)
			object = mxModel(object, mxCI(CIs2Add, interval = level))
			message("added ", length(CIs2Add), " CIs")
		} else {
			stop("I only know how to add smart CIs for CP models so far. Sorry")
		}
	} else if (parm == "existing"){
		# nothing to do
	} else {
		# user requesting 1 new CI
		# TODO umxConfint: Check that these are valid and not duplicates
		object = mxModel(object, mxCI(parm, interval = level))
	}

	# 2. Run CIs if requested
	if(run) {
		# Check there are some in existence
		if(!umx_has_CIs(object, "intervals")) {
			message("This model has no CIs yet. Perhaps you wanted to use parm = 'all' for CIs on all free parameters? Or to a list of labels?")
		}else{
			# object = mxRun(object, intervals = TRUE)
			object = omxRunCI(object, optimizer = optimizer)
		}
	}
	# 3. Report CIs
	if(!umx_has_CIs(object, "both")) {
		if(run == FALSE){
			message("Some CIs have been requested, but have not yet been run. Add ", omxQuotes("run = TRUE"), " to your umxConfint() call to run them.\n",
			"To store the model run capture it from umxConfint like this:\n",
			"m1 = umxConfint(m1, run = TRUE)")
		} else if(length(object$intervals)==0){
			message("No CIs requested...")
		} else{
			message("hmmm... you wanted it run, but I don't see any computed CIs despite there being ", length(object$intervals), " requested...",
			"\nThat's a bug. Please report it to timothy.c.bates@gmail.com")
		}
	} else {
		# model has CIs and they have been run
		# 1. Summarize model
		model_summary = summary(object, verbose = TRUE)
		# 2. Extract CIs and details, and arrange for merging
		CIdetail = model_summary$CIdetail
		CIdetail = CIdetail[, c("parameter", "value", "side", "diagnostic", "statusCode")]
		CIdetail$diagnostic = as.character(CIdetail$diagnostic)
		CIdetail$statusCode = as.character(CIdetail$statusCode)
		CIdetail$diagnostic = namez(CIdetail$diagnostic, pattern = "alpha level not reached"         , replacement = "alpha hi")
		CIdetail$statusCode = namez(CIdetail$statusCode, pattern = "infeasible non-linear constraint", replacement = "constrained")
		CIdetail$statusCode = namez(CIdetail$statusCode, pattern = "iteration limit/blue"            , replacement = "blue")

		CIs = model_summary$CI
		CIs$parameter = row.names(CIs)
		row.names(CIs) <- NULL
		CIs = CIs[, c("parameter", "estimate", "lbound", "ubound", "note")]
		intersect(names(CIdetail), names(CIs))
		tmp = merge(CIs, CIdetail[CIdetail$side == "lower", ], by = "parameter", all.x = TRUE)
		tmp = merge(tmp, CIdetail[CIdetail$side == "upper", ], by = "parameter", all.x = TRUE, suffixes = c(".lower",".upper"))
		tmp$side.lower = NULL
		tmp$side.upper = NULL

		# 3. Format CIs
		model_CIs   = round(CIs[,c("lbound", "estimate", "ubound")], 3)
		model_CI_OK = object$output$confidenceIntervalCodes
		colnames(model_CI_OK) <- c("lbound Code", "ubound Code")
		model_CIs =	cbind(round(model_CIs, 3), model_CI_OK)
		print(model_CIs)
		npsolMessages <- list(
		'1' = 'The final iterate satisfies the optimality conditions to the accuracy requested, but the sequence of iterates has not yet converged. NPSOL was terminated because no further improvement could be made in the merit function (Mx status GREEN).',
		'2' = 'The linear constraints and bounds could not be satisfied. The problem has no feasible solution.',
		'3' = 'The nonlinear constraints and bounds could not be satisfied. The problem may have no feasible solution.',
		'4' = 'The major iteration limit was reached (Mx status BLUE).',
		'5' = 'not used',
		'6' = 'The model does not satisfy the first-order optimality conditions to the required accuracy, and no improved point for the merit function could be found during the final linesearch (Mx status RED)',
		'7' = 'The function derivatives returned by funcon or funobj appear to be incorrect.',
		'8' = 'not used',
		'9' = 'An input parameter was invalid')
		if(!is.null(model_CI_OK) && any(model_CI_OK !=0) && showErrorCodes){
			codeList = c(model_CI_OK[,"lbound Code"], model_CI_OK[,"ubound Code"])
			relevantCodes = unique(codeList); relevantCodes = relevantCodes[relevantCodes !=0]
			for(i in relevantCodes) {
			   print(paste0(i, ": ", npsolMessages[i][[1]]))
			}
		}
	}
	invisible(object)
}

# 1789(liberty+terror), 1815 (liberty+inequality)

#' Add (and, optionally, run) confidence intervals to a structural model.
#'
#' umxCI adds mxCI() calls for requested (default all) parameters in a model, 
#' runs these CIs if necessary, and reports them in a neat summary.
#'
#' @details 
#' umxCI also reports any problems computing a CI. The codes are standard OpenMx errors and warnings
#' \itemize{
#' \item 1: The final iterate satisfies the optimality conditions to the accuracy requested, but the sequence of iterates has not yet converged. NPSOL was terminated because no further improvement could be made in the merit function (Mx status GREEN)
#' \item 2: The linear constraints and bounds could not be satisfied. The problem has no feasible solution.
#' \item 3: The nonlinear constraints and bounds could not be satisfied. The problem may have no feasible solution.
#' \item 4: The major iteration limit was reached (Mx status BLUE).
#' \item 6: The model does not satisfy the first-order optimality conditions to the required accuracy, and no improved point for the merit function could be found during the final linesearch (Mx status RED)
#' \item 7: The function derivatives returned by funcon or funobj appear to be incorrect.
#' \item 9: An input parameter was invalid
#' }
#' 
#' @param model The \code{\link{mxModel}} you wish to report \code{\link{mxCI}}s on
#' @param which What CIs to add: c("ALL", NA, "list of your making")
#' @param remove = FALSE (if set, removes existing specified CIs from the model)
#' @param run Whether or not to compute the CIs. Valid values = "no" (default), "yes", "if necessary".
#' 'show' means print the intervals if computed, or list their names if not.
#' @param interval The interval for newly added CIs (defaults to 0.95)
#' @param type The type of CI (defaults to "both", options are "lower" and  "upper")
#' @param showErrorCodes Whether to show errors (default == TRUE)
#' @details If runCIs is FALSE, the function simply adds CIs to be computed and returns the model.
#' @return - \code{\link{mxModel}}
#' @family Reporting functions
#' @seealso - \code{\link[stats]{confint}}, \code{\link{umxConfint}}, \code{\link{umxCI}}, \code{\link{umxModify}}
#' @references - https://www.github.com/tbates/umx/
#' @export
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' m1$intervals # none yet - empty list()
#' m1 = umxCI(m1)
#' m1$intervals # $G_to_x1
#' m1 = umxCI(m1, remove = TRUE) # remove CIs from the model and return it
#' 
#' # ========================
#' # = A twin model example =
#' # ========================
#' data(twinData) 
#' mzData <- subset(twinData, zygosity == "MZFF")
#' dzData <- subset(twinData, zygosity == "DZFF")
#' m1 = umxACE(selDVs = c("bmi1","bmi2"), dzData = dzData, mzData = mzData)
#' \dontrun{
#' umxCI(m1, run = "show") # show what will be requested
#' umxCI(m1, run = "yes") # actually compute the CIs
#' # Don't force update of CIs, but if they were just added, then calculate them
#' umxCI(m1, run = "if necessary")
#' m1 = umxCI(m1, remove = TRUE) # remove them all
#' m1$intervals # none!
#' # Show what parameters are available to get CIs on
#' umxParameters(m1) 
#' # Request a CI by label:
#' m1 = umxCI(m1, "a_r1c1", run = "yes")
#' }
umxCI <- function(model = NULL, which = c("ALL", NA, "list of your making"), remove = FALSE, run = c("no", "yes", "if necessary", "show"), interval = 0.95, type = c("both", "lower", "upper"), showErrorCodes = TRUE) {
	# Note: OpenMx now overloads confint, returning SE-based intervals.
	run = match.arg(run)
	which = umx_default_option(which, c("ALL", NA, "list of your making"), check = FALSE)
	if(remove){
		if(which == "ALL"){
			CIs = names(model$intervals)
		} else {
			CIs = which 
		}
		if(length(names(model$intervals)) > 0){
			model = mxModel(model, mxCI(CIs), remove = TRUE)
		} else {
			message("model has no intervals to remove")
		}
		invisible(model)
	} else {
		# Adding CIs
		# TODO Avoid duplicating existing CIs
		# TODO Add each CI individually
		# TODO Break them out into separate models and reassemble if on cluster?
		if(is.na(which)){
			# nothing to add
		} else {
			if(which == "ALL"){
				CIs = names(omxGetParameters(model, free = TRUE))
			} else {
				CIs = which 
			}
			model = mxModel(model, mxCI(CIs, interval = interval, type = type))
		}
	}
	if(run == "yes" | (!umx_has_CIs(model) & run == "if necessary")) {
		model = mxRun(model, intervals = TRUE)
	} else {
		message("Not running CIs, run == ", run)
	}

	if(run == "show") {
		print("CI requests in the model:")
		print(names(model$intervals))
	}
	if(umx_has_CIs(model)){
		message("### Computed CIs in model ", model$name)
		umxConfint(model, showErrorCodes = showErrorCodes)
	}
	invisible(model)
}

#' Shows a compact, publication-style, summary of umx models
#'
#' @description
#' Report the fit of a OpenMx model or specialized model class (such as ACE, CP etc.)
#' in a compact form suitable for reporting in a journal.
#'
#' See documentation for RAM models summary here: \code{\link{umxSummary.MxModel}}.
#' 
#' View documentation on the ACE model subclass here: \code{\link{umxSummaryACE}}.
#' 
#' View documentation on the ACEv model subclass here: \code{\link{umxSummaryACEv}}.
#' 
#' View documentation on the IP model subclass here: \code{\link{umxSummaryIP}}.
#' 
#' View documentation on the CP model subclass here: \code{\link{umxSummaryCP}}.
#' 
#' View documentation on the GxE model subclass here: \code{\link{umxSummaryGxE}}.
#'
#' @param model The \code{\link{mxModel}} whose fit will be reported
#' @param ... Other parameters to control model summary
#' @family Reporting Functions
#' @family Core Modeling Functions
#' \url{https://www.github.com/tbates/umx}
#' @export
umxSummary <- function(model, ...){
	UseMethod("umxSummary", model)
}

#' @export
umxSummary.default <- function(model, ...){
	stop("umxSummary is not defined for objects of class:", class(model))
}

#' Shows a compact, publication-style, summary of a RAM model
#'
#' Report the fit of a model in a compact form suitable for a journal. Emits a "warning" 
#' when model fit is worse than accepted criterion (TLI >= .95 and RMSEA <= .06; (Hu & Bentler, 1999; Yu, 2002).
#' 
#' Note: For some (multi-group) models, you will need to fall back on \code{\link{summary}}
#' 
#' CIs and Identification
#' This function uses the standard errors reported by OpenMx to produce the CIs you see in umxSummary
#' These are used to derive confidence intervals based on the formula 95%CI = estimate +/- 1.96*SE)
#' 
#' Sometimes they appear NA. This often indicates a model which is not identified (see\url{http://davidakenny.net/cm/identify.htm}).
#' This can include empirical under-identification - for instance two factors
#' that are essentially identical in structure. use \code{\link{mxCheckIdentification}} to check identification.
#' 
#' One or more paths estimated at or close to zero suggests that fixing one or two of 
#' these to zero may fix the standard error calculation, 
#' and alleviate the need to estimate likelihood-based or bootstrap CIs
#' 
#' If factor loadings can flip sign and provide identical fit, this creates another form of 
#' under-identification and can break confidence interval estimation.
#' Fixing a factor loading to 1 and estimating factor variances can help here.
#'
#' @aliases umxSummary.MxModel
#' @param model The \code{\link{mxModel}} whose fit will be reported
#' @param refModels Saturated models if needed for fit indices (see example below:
#' 	If NULL will be competed on demand. If FALSE will not be computed. Only needed for raw data.
#' @param showEstimates What estimates to show. By default, the raw estimates are shown 
#' (Options = c("raw", "std", "none", "both").
#' @param digits How many decimal places to report (default = 2)
#' @param report If "html", then show results in browser (alternative = "markdown")
#' @param filter whether to show significant paths (SIG) or NS paths (NS) or all paths (ALL)
#' @param SE Whether to compute SEs... defaults to TRUE. In rare cases, you might need to turn off to avoid errors.
#' @param RMSEA_CI Whether to compute the CI on RMSEA (Defaults to FALSE)
#' @param matrixAddresses Whether to show "matrix address" columns (Default = FALSE)
#' @param std deprecated: use show = "std" instead!
#' @param ... Other parameters to control model summary
#' @family Reporting functions
#' @seealso - \code{\link{umxRun}}
#' @references - Hu, L., & Bentler, P. M. (1999). Cutoff criteria for fit indexes in covariance 
#'  structure analysis: Conventional criteria versus new alternatives. Structural Equation Modeling, 6, 1-55. 
#'
#'  - Yu, C.Y. (2002). Evaluating cutoff criteria of model fit indices for latent variable models
#'  with binary and continuous outcomes. University of California, Los Angeles, Los Angeles.
#'  Retrieved from \url{https://www.statmodel.com/download/Yudissertation.pdf}
#' 
#' \url{https://tbates.github.io}
#' 
#' @export
#' @import OpenMx
#' @return - parameterTable returned invisibly, if estimates requested
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor",
#' 	data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' umxSummary(m1, showEstimates = "std")
#' # output as latex
#' umx_set_table_format("latex")
#' umxSummary(m1, showEstimates = "std")
#' umx_set_table_format("markdown")
#' # output as raw
#' umxSummary(m1, show = "raw")
#' m1 <- mxModel(m1,
#'   mxData(demoOneFactor[1:100,], type = "raw"),
#'   umxPath(mean = manifests),
#'   umxPath(mean = latents, fixedAt = 0)
#' )
#' m1 <- mxRun(m1)
#' umxSummary(m1, showEstimates = "std", filter = "NS")
umxSummary.MxModel <- function(model, refModels = NULL, showEstimates = c("raw", "std", "none", "both"), digits = 2, report = c("markdown", "html"), filter = c("ALL", "NS", "SIG"), SE = TRUE, RMSEA_CI = FALSE, matrixAddresses = FALSE, std = "deprecated", ...){
	# TODO make table take lists of models...
	if(std != "deprecated"){
		stop("use show = 'std', not std = TRUE")
	}
	report = match.arg(report)
	filter = match.arg(filter)
	showEstimates = match.arg(showEstimates)

	message("?umxSummary showEstimates='raw|std', digits, report= 'html', filter= 'NS' & more")
	
	# If the filter is not default, user must want something: Assume it's what would have been the default...
	if( filter != "ALL" & showEstimates == "none") {
		showEstimates = "raw"
	}else if(showEstimates == "std" && SE == FALSE){
		# message("SE must be TRUE to show std, overriding to set SE = TRUE")
		SE = TRUE
	}
	umx_has_been_run(model, stop = TRUE)
	if(is.null(refModels)) {
		# SaturatedModels not passed in from outside, so get them from the model
		# TODO Improve efficiency: Compute summary only once by detecting when SaturatedLikelihood is missing
		modelSummary = summary(model)
		if(is.null(model$data)){
			# TODO model with no data - no saturated solution?
			message("Top model doesn't contain data. You might want to use summary() instead of umxSummary() for this model.")
		} else if(is.na(modelSummary$SaturatedLikelihood)){
			# no SaturatedLikelihood, compute refModels
			refModels = mxRefModels(model, run = TRUE)
			modelSummary = summary(model, refModels = refModels)
		}
	} else if (refModels == FALSE){
		modelSummary = summary(model) # Don't use or generate refModels		
	}else{
		modelSummary = summary(model, refModels = refModels) # Use user-supplied refModels		
	}

	# DisplayColumns
	if(showEstimates != "none"){
		parameterTable = mxStandardizeRAMpaths(model, SE = SE) # Compute standard errors
		nSubModels = length(model$submodels)
		if(nSubModels > 0){
			tmp = parameterTable
			parameterTable = tmp[[1]]
			if(nSubModels > 1){
				for (i in 2:nSubModels) {
					parameterTable = rbind(parameterTable, tmp[[i]])
				}			
			}
		}
		#          name    label  matrix   row         col    Raw.Value  Raw.SE   Std.Value    Std.SE
		# 1  Dep.A[6,1]    age    A        mean_sdrr   age   -0.37       0.0284   -0.372350    .028
		# Raw.SE is new
		names(parameterTable) <- c("label", "name", "matrix", "row", "col", "Estimate", "SE", "Std.Estimate", "Std.SE")

		if(matrixAddresses){
			nameing = c("name", "matrix", "row", "col")
		} else {
			nameing = c("name")
		}
		if(showEstimates == "both") {
			namesToShow = c(nameing, "Estimate", "SE", "Std.Estimate", "Std.SE")
		} else if(showEstimates == "std"){
			namesToShow = c(nameing, "Std.Estimate", "Std.SE", "CI")
		}else{ # must be raw
			namesToShow = c(nameing, "Estimate", "SE")					
		}
		if("CI" %in% namesToShow){
			parameterTable$sig = TRUE
			parameterTable$CI  = ""
			for(i in 1:dim(parameterTable)[1]) {
				# TODO we only show SE-based CI for std estimates so far
				est   = parameterTable[i, "Std.Estimate"]
				CI95  = parameterTable[i, "Std.SE"] * 1.96
				bounds = c(est - CI95, est + CI95)

				if(any(is.na(bounds))) {
					# protect cases with SE == NA from evaluation for significance
				} else {
					if (any(bounds <= 0) & any(bounds >= 0)){
						parameterTable[i, "sig"] = FALSE
					}
					if(est < 0){
						parameterTable[i, "CI"] = paste0(round(est, digits), " [", round(est - CI95, digits), ", ", round(est + CI95, digits), "]")
					} else {
						parameterTable[i, "CI"] = paste0(round(est, digits), " [", round(est - CI95, digits), ", ", round(est + CI95, digits), "]")
					}
				}
			}
		}
		if(filter == "NS") {
			toShow = parameterTable[parameterTable$sig == FALSE, namesToShow]
		} else if(filter == "SIG") {
			toShow = parameterTable[parameterTable$sig == TRUE, namesToShow]
		} else {
			toShow = parameterTable[,namesToShow]
		}
		if(report == "html"){
			umx_print(toShow, digits = digits, file = "tmp.html");
		} else {
			umx_print(toShow, digits = digits, na.print = "", zero.print = "0", justify = "none")
		}
	} else {
		# message("For estimates, umxSummary(..., showEstimates = 'std', 'raw', or 'both')")
	}
	with(modelSummary, {
		if(!is.finite(TLI)){
			TLI_OK = "OK"
		} else {
			if(TLI > .95) {
				TLI_OK = "OK"
				} else {
					TLI_OK = "bad"
				}
			}
			if(!is.finite(RMSEA)) {
				RMSEA_OK = "OK"
			} else {
				if(RMSEA < .06){
				RMSEA_OK = "OK"
				} else {
					RMSEA_OK = "bad"
				}
			}
			if(report == "table"){
				x = data.frame(cbind(model$name, round(Chi,2), formatC(p, format="g"), round(CFI,3), round(TLI,3), round(RMSEA, 3)))
				names(x) = c("model","\u03C7","p","CFI", "TLI","RMSEA") # \u03A7 is unicode for chi
				print(x)
			} else {
				if(RMSEA_CI){
					RMSEA_CI = RMSEA(modelSummary)$txt
				} else {
					RMSEA_CI = paste0("RMSEA = ", round(RMSEA, 3))
				}
				x = paste0(
					"\u03C7\u00B2(", ChiDoF, ") = ", round(Chi, 2), # was A7
					", p "      , umx_APA_pval(p, .001, 3, addComparison = TRUE),
					"; CFI = "  , round(CFI, 3),
					"; TLI = "  , round(TLI, 3),
					"; ", RMSEA_CI
					)
				print(x)
				if(TLI_OK != "OK"){
					message("TLI is worse than desired")
				}
				if(RMSEA_OK != "OK"){
					message("RMSEA is worse than desired")
				}
			}
	})
	
	if(!is.null(model$output$confidenceIntervals)){
		print(model$output$confidenceIntervals)
	}
	if(showEstimates != "none"){ # return these as  invisible for the user to filer, sort etc.
		if(filter == "NS"){
			invisible(parameterTable[parameterTable$sig == FALSE, namesToShow])
		}else if(filter == "SIG"){
			invisible(parameterTable[parameterTable$sig == TRUE, namesToShow])
		}else{
			invisible(parameterTable[,namesToShow])
		}
	}
}

#' Shows a compact, publication-style, summary of a umx Cholesky ACE model
#'
#' Summarize a fitted Cholesky model returned by \code{\link{umxACE}}. Can control digits, report comparison model fits,
#' optionally show the Rg (genetic and environmental correlations), and show confidence intervals. the report parameter allows
#' drawing the tables to a web browser where they may readily be copied into non-markdown programs like Word.
#'
#' See documentation for other umx models here: \code{\link{umxSummary}}.
#' 
#' @aliases umxSummary.MxModelACE
#' @param model an \code{\link{mxModel}} to summarize
#' @param digits round to how many digits (default = 2)
#' @param file The name of the dot file to write: "name" = use the name of the model.
#' Defaults to NA = do not create plot output
#' @param comparison you can run mxCompare on a comparison model (NULL)
#' @param std Whether to standardize the output (default = TRUE)
#' @param showRg = whether to show the genetic correlations (FALSE)
#' @param CIs Whether to show Confidence intervals if they exist (T)
#' @param returnStd Whether to return the standardized form of the model (default = FALSE)
#' @param report If "html", then open an html table of the results
#' @param extended how much to report (FALSE)
#' @param zero.print How to show zeros (".")
#' @param ... Other parameters to control model summary
#' @return - optional \code{\link{mxModel}}
#' @export
#' @family Twin Modeling Functions
#' @family Reporting functions
#' @seealso - \code{\link{umxACE}}, \code{\link{plot.MxModelACE}}, \code{\link{umxModify}}
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(twinData)
#' selDVs = c("bmi1", "bmi2")
#' mzData <- subset(twinData, zygosity == "MZFF")
#' dzData <- subset(twinData, zygosity == "DZFF")
#' m1 = umxACE(selDVs = selDVs, dzData = dzData, mzData = mzData)
#' umxSummary(m1)
#' \dontrun{
#' umxSummaryACE(m1, file = NA);
#' umxSummaryACE(m1, file = "name", std = TRUE)
#' stdFit = umxSummaryACE(m1, returnStd = TRUE);
#' }
umxSummaryACE <- function(model, digits = 2, file = getOption("umx_auto_plot"), comparison = NULL, std = TRUE, showRg = FALSE, CIs = TRUE, report = c("markdown", "html"), returnStd = FALSE, extended = FALSE, zero.print = ".", ...) {
	report = match.arg(report)
	# depends on R2HTML::HTML
	if(typeof(model) == "list"){ # call self recursively
		for(thisFit in model) {
			message("Output for Model: ", thisFit$name)
			umxSummaryACE(thisFit, digits = digits, file = file, showRg = showRg, std = std, comparison = comparison, CIs = CIs, returnStd = returnStd, extended = extended, zero.print = zero.print, report = report)
		}
	} else {
		umx_has_been_run(model, stop = TRUE)
		umx_show_fit_or_comparison(model, comparison = comparison, digits = digits)
		selDVs = dimnames(model$top.expCovMZ)[[1]]
		nVar <- length(selDVs)/2;
		# TODO umxSummaryACE these already exist if a_std exists..
		# TODO replace all this with umx_standardizeACE
		# Calculate standardized variance components
		a  <- mxEval(top.a, model); # Path coefficients
		c  <- mxEval(top.c, model);
		e  <- mxEval(top.e, model);
		A  <- mxEval(top.A, model); # Variances
		C  <- mxEval(top.C, model);
		E  <- mxEval(top.E, model);

		if(std){
			message("Standardized solution")
			Vtot = A + C + E;         # Total variance
			I  <- diag(nVar);         # nVar Identity matrix
			SD <- solve(sqrt(I * Vtot)) # Inverse of diagonal matrix of standard deviations
			# (same as "(\sqrt(I.Vtot))~"

			# Standardized _path_ coefficients ready to be stacked together
			a_std <- SD %*% a; # Standardized path coefficients
			c_std <- SD %*% c;
			e_std <- SD %*% e;
			aClean = a_std
			cClean = c_std
			eClean = e_std
		} else {
			message("Raw solution")
			aClean = a
			cClean = c
			eClean = e
		}

		aClean[upper.tri(aClean)] = NA
		cClean[upper.tri(cClean)] = NA
		eClean[upper.tri(eClean)] = NA
		rowNames = sub("(_T)?1$", "", selDVs[1:nVar])
		Estimates = data.frame(cbind(aClean, cClean, eClean), row.names = rowNames, stringsAsFactors = FALSE);

		if(model$top$dzCr$values == .25){
			colNames = c("a", "d", "e")
		} else {
			colNames = c("a", "c", "e")
		}
		names(Estimates) = paste0(rep(colNames, each = nVar), rep(1:nVar));
		Estimates = umx_print(Estimates, digits = digits, zero.print = zero.print)
		if(report == "html"){
			# depends on R2HTML::HTML
			R2HTML::HTML(Estimates, file = "tmp.html", Border = 0, append = F, sortableDF = T); 
			umx_open("tmp.html")
		}
	
		if(extended == TRUE) {
			message("Unstandardized path coefficients")
			aClean = a
			cClean = c
			eClean = e
			aClean[upper.tri(aClean)] = NA
			cClean[upper.tri(cClean)] = NA
			eClean[upper.tri(eClean)] = NA
			unStandardizedEstimates = data.frame(cbind(aClean, cClean, eClean), row.names = rowNames);
			names(unStandardizedEstimates) = paste0(rep(colNames, each = nVar), rep(1:nVar));
			umx_print(unStandardizedEstimates, digits = digits, zero.print = zero.print)
		}

	# Pre & post multiply covariance matrix by inverse of standard deviations
	if(showRg) {
		message("Genetic correlations")
		NAmatrix <- matrix(NA, nVar, nVar);
		rA = tryCatch(solve(sqrt(I*A)) %*% A %*% solve(sqrt(I*A)), error = function(err) return(NAmatrix)); # genetic correlations
		rC = tryCatch(solve(sqrt(I*C)) %*% C %*% solve(sqrt(I*C)), error = function(err) return(NAmatrix)); # C correlations
		rE = tryCatch(solve(sqrt(I*E)) %*% E %*% solve(sqrt(I*E)), error = function(err) return(NAmatrix)); # E correlations
		rAClean = rA
		rCClean = rC
		rEClean = rE
		rAClean[upper.tri(rAClean)] = NA
		rCClean[upper.tri(rCClean)] = NA
		rEClean[upper.tri(rEClean)] = NA
		genetic_correlations = data.frame(cbind(rAClean, rCClean, rEClean), row.names = rowNames);
		names(genetic_correlations) <- rowNames
	 	# Make a nice table.
		names(genetic_correlations) = paste0(rep(c("rA", "rC", "rE"), each = nVar), rep(1:nVar));
		umx_print(genetic_correlations, digits = digits, zero.print = zero.print)
	}
	hasCIs = umx_has_CIs(model)
	if(hasCIs & CIs) {
		# TODO umxACE CI code: Need to refactor into some function calls...
		# TODO and then add to umxSummaryIP and CP
		message("Creating CI-based report!")
		# CIs exist, get lower and upper CIs as a dataframe
		CIlist = data.frame(model$output$confidenceIntervals)
		# Drop rows fixed to zero
		CIlist = CIlist[(CIlist$lbound != 0 & CIlist$ubound != 0),]
		# Discard rows named NA
		CIlist = CIlist[!grepl("^NA", row.names(CIlist)), ]
		# TODO fix for singleton CIs
		# THIS IS NOT NEEDED: confidenceIntervals come with estimate in the middle now...
		# These can be names ("top.a_std[1,1]") or labels ("a_r1c1")
		# imxEvalByName finds them both
		# outList = c();
		# for(aName in row.names(CIlist)) {
		# 	outList <- append(outList, imxEvalByName(aName, model))
		# }
		# # Add estimates into the CIlist
		# CIlist$estimate = outList
		# reorder to match summary
		# CIlist <- CIlist[, c("lbound", "estimate", "ubound")]
		CIlist$fullName = row.names(CIlist)
		# Initialise empty matrices for the CI results
		rows = dim(model$top$matrices$a$labels)[1]
		cols = dim(model$top$matrices$a$labels)[2]
		a_CI = c_CI = e_CI = matrix(NA, rows, cols)

		# iterate over each CI
		labelList = imxGenerateLabels(model)	
		rowCount = dim(CIlist)[1]
		# return(CIlist)
		for(n in 1:rowCount) { # n = 1
			thisName = row.names(CIlist)[n] # thisName = "a11"
				# convert labels to [bracket] style
				if(!umx_has_square_brackets(thisName)) {
				nameParts = labelList[which(row.names(labelList) == thisName),]
				CIlist$fullName[n] = paste(nameParts$model, ".", nameParts$matrix, "[", nameParts$row, ",", nameParts$col, "]", sep = "")
			}
			fullName = CIlist$fullName[n]

			thisMatrixName = sub(".*\\.([^\\.]*)\\[.*", replacement = "\\1", x = fullName) # .matrix[
			thisMatrixRow  = as.numeric(sub(".*\\[(.*),(.*)\\]", replacement = "\\1", x = fullName))
			thisMatrixCol  = as.numeric(sub(".*\\[(.*),(.*)\\]", replacement = "\\2", x = fullName))
			CIparts    = round(CIlist[n, c("estimate", "lbound", "ubound")], digits)
			thisString = paste0(CIparts[1], " [",CIparts[2], ", ",CIparts[3], "]")

			if(grepl("^a", thisMatrixName)) {
				a_CI[thisMatrixRow, thisMatrixCol] = thisString
			} else if(grepl("^c", thisMatrixName)){
				c_CI[thisMatrixRow, thisMatrixCol] = thisString
			} else if(grepl("^e", thisMatrixName)){
				e_CI[thisMatrixRow, thisMatrixCol] = thisString
			} else{
				stop(paste("Illegal matrix name: must begin with a, c, or e. You sent: ", thisMatrixName))
			}
		}
		# TODO Check the merge of a_, c_ and e_CI INTO the output table works with more than one variable
		# TODO umxSummaryACE: Add option to use mxSE
		# print(a_CI)
		# print(c_CI)
		# print(e_CI)
		Estimates = data.frame(cbind(a_CI, c_CI, e_CI), row.names = rowNames, stringsAsFactors = FALSE)
		names(Estimates) = paste0(rep(colNames, each = nVar), rep(1:nVar));
		Estimates = umx_print(Estimates, digits = digits, zero.print = zero.print)
		if(report == "html"){
			# depends on R2HTML::HTML
			R2HTML::HTML(Estimates, file = "tmpCI.html", Border = 0, append = F, sortableDF = T); 
			umx_open("tmpCI.html")
		}
		CI_Fit = model
		CI_Fit$top$a$values = a_CI
		CI_Fit$top$c$values = c_CI
		CI_Fit$top$e$values = e_CI
	} # end Use CIs
	} # end list catcher?
	
	
	if(!is.na(file)) {
		# message("making dot file")
		if(hasCIs & CIs){
			umxPlotACE(CI_Fit, file = file, std = FALSE)
		} else {
			umxPlotACE(model, file = file, std = std)
		}
	}
	if(returnStd) {
		if(CIs){
			message("If you asked for CIs, returned model is not runnable (contains CIs not parameter values)")
		}
		umx_standardize_ACE(model)
	}
}

#' @export
umxSummary.MxModelACE <- umxSummaryACE

#' Present results of a twin ACE-model with covariates in table and graphical forms.
#'
#' Summarize a Cholesky model with covariates, as returned by \code{\link{umxACEcov}}
#'
#' @aliases umxSummary.MxModelACEcov
#' @param model a \code{\link{umxACEcov}} model to summarize
#' @param digits round to how many digits (default = 2)
#' @param file The name of the dot file to write: NA = none; "name" = use the name of the model
#' @param returnStd Whether to return the standardized form of the model (default = FALSE)
#' @param extended how much to report (FALSE)
#' @param showRg = whether to show the genetic correlations (FALSE)
#' @param std = whether to show the standardized model (TRUE)
#' @param comparison you can run mxCompare on a comparison model (NULL)
#' @param CIs Whether to show Confidence intervals if they exist (TRUE)
#' @param zero.print How to show zeros (".")
#' @param report If "html", then open an html table of the results.
#' @param ... Other parameters to control model summary
#' @return - optional \code{\link{mxModel}}
#' @export
#' @family Twin Modeling Functions
#' @seealso - \code{\link{umxACEcov}} 
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(twinData)
#' selDVs = c("bmi1", "bmi2")
#' mzData <- subset(twinData, zygosity == "MZFF")
#' dzData <- subset(twinData, zygosity == "DZFF")
#' m1 = umxACE(selDVs = selDVs, dzData = dzData, mzData = mzData)
#' m1 = umxRun(m1)
#' umxSummaryACE(m1)
#' \dontrun{
#' umxSummaryACE(m1, file = NA);
#' umxSummaryACE(m1, file = "name", std = TRUE)
#' stdFit = umxSummaryACE(m1, returnStd = TRUE);
#' }
umxSummaryACEcov <- function(model, digits = 2, file = getOption("umx_auto_plot"), returnStd = FALSE, extended = FALSE, showRg = FALSE, std = TRUE, comparison = NULL, CIs = TRUE, zero.print = ".", report = c("1", "2", "html"), ...) {
	report = match.arg(report)
	# depends on R2HTML::HTML
	if(typeof(model) == "list"){ # call self recursively
		for(thisFit in model) {
			message("Output for Model: ", thisFit$name)
			umxSummaryACEcov(thisFit, digits = digits, file = file, returnStd = returnStd, extended = extended, showRg = showRg, std = std, comparison = comparison, CIs = CIs, zero.print = zero.print, report = report)
		}
	} else {
	umx_has_been_run(model, stop = TRUE)
	umx_show_fit_or_comparison(model, comparison = comparison, digits = digits)
	selDVs = dimnames(model$top$a)[[1]]
	# selDVs = dimnames(model$top.expCovMZ)[[1]]
	nDV <- length(selDVs);
	# Calculate standardized variance components
	a  <- mxEval(top.a, model); # Path coefficients
	c  <- mxEval(top.c, model);
	e  <- mxEval(top.e, model);

	A  <- mxEval(top.A, model); # Variances
	C  <- mxEval(top.C, model);
	E  <- mxEval(top.E, model);
	Vtot = A + C + E; # Total variance
	Iden  <- diag(nDV);  # nDV Identity matrix
	SD <- solve(sqrt(Iden * Vtot)) # Inverse of diagonal matrix of standard deviations
	# (same as "(\sqrt(Iden.Vtot))~"

	# Standardized _path_ coefficients ready to be stacked together
	a_std <- SD %*% a; # Standardized path coefficients
	c_std <- SD %*% c;
	e_std <- SD %*% e;

	if(std){
		message("Standardized solution")
		aClean = a_std
		cClean = c_std
		eClean = e_std
	} else {
		message("Raw solution")
		aClean = a
		cClean = c
		eClean = e
	}

	aClean[upper.tri(aClean)] = NA
	cClean[upper.tri(cClean)] = NA
	eClean[upper.tri(eClean)] = NA
	rowNames = sub("(_T)?1$", "", selDVs[1:nDV])
	Estimates = data.frame(cbind(aClean, cClean, eClean), row.names = rowNames);

	names(Estimates) = paste0(rep(c("a", "c", "e"), each = nDV), rep(1:nDV));

	Estimates = umx_print(Estimates, digits = digits, zero.print = zero.print)
	if(report == "html"){
		# depends on R2HTML::HTML
		R2HTML::HTML(Estimates, file = "tmp.html", Border = 0, append = F, sortableDF = T); 
		umx_open("tmp.html")
	}

	if(extended == TRUE) {
		message("Unstandardized path coefficients")
		aClean = a
		cClean = c
		eClean = e
		aClean[upper.tri(aClean)] = NA
		cClean[upper.tri(cClean)] = NA
		eClean[upper.tri(eClean)] = NA
		unStandardizedEstimates = data.frame(cbind(aClean, cClean, eClean), row.names = rowNames);
		names(unStandardizedEstimates) = paste0(rep(c("a", "c", "e"), each = nDV), rep(1:nDV));
		umx_print(unStandardizedEstimates, digits = digits, zero.print = zero.print)
	}

	# Pre & post multiply covariance matrix by inverse of standard deviations
	if(showRg) {
		message("Genetic correlations")
		NAmatrix <- matrix(NA, nDV, nDV);
		rA = tryCatch(solve(sqrt(Iden * A)) %*% A %*% solve(sqrt(Iden * A)), error = function(err) return(NAmatrix)); # genetic correlations
		rC = tryCatch(solve(sqrt(Iden * C)) %*% C %*% solve(sqrt(Iden * C)), error = function(err) return(NAmatrix)); # C correlations
		rE = tryCatch(solve(sqrt(Iden * E)) %*% E %*% solve(sqrt(Iden * E)), error = function(err) return(NAmatrix)); # E correlations
		rAClean = rA
		rCClean = rC
		rEClean = rE
		rAClean[upper.tri(rAClean)] = NA
		rCClean[upper.tri(rCClean)] = NA
		rEClean[upper.tri(rEClean)] = NA
		genetic_correlations = data.frame(cbind(rAClean, rCClean, rEClean), row.names = rowNames);
		names(genetic_correlations) <- rowNames
	 	# Make a nice-ish table
		names(genetic_correlations) = paste0(rep(c("rA", "rC", "rE"), each=nDV), rep(1:nDV));
		umx_print(genetic_correlations, digits=digits, zero.print = zero.print)
	}
	stdFit = model
	hasCIs = umx_has_CIs(model)
	if(hasCIs & CIs) {
		# TODO Need to refactor this into some function calls...
		# TODO and then add to umxSummaryIP and CP
		message("Creating CI-based report!")
		# CIs exist, get the lower and uppper CIs as a dataframe
		CIlist = data.frame(model$output$confidenceIntervals)
		# Drop rows fixed to zero
		CIlist = CIlist[(CIlist$lbound != 0 & CIlist$ubound != 0),]
		# discard rows named NA
		CIlist = CIlist[!grepl("^NA", row.names(CIlist)), ]

		# # Add estimates into the CIlist
		# CIlist$estimate = outList
		# reorder to match summary
		CIlist <- CIlist[, c("lbound", "estimate", "ubound")] 
		CIlist$fullName = row.names(CIlist)
		# Initialise empty matrices for the standardized results
		rows = dim(model$top$matrices$a$labels)[1]
		cols = dim(model$top$matrices$a$labels)[2]
		a_std = c_std = e_std = matrix(NA, rows, cols)

		# iterate over each CI
		labelList = imxGenerateLabels(model)			
		rowCount = dim(CIlist)[1]
		# return(CIlist)
		for(n in 1:rowCount) { # n = 1
			thisName = row.names(CIlist)[n] # thisName = "a11"
			# convert labels to [bracket] style
				if(!umx_has_square_brackets(thisName)) {
				nameParts = labelList[which(row.names(labelList) == thisName),]
				CIlist$fullName[n] = paste(nameParts$model, ".", nameParts$matrix, "[", nameParts$row, ",", nameParts$col, "]", sep = "")
			}
			fullName = CIlist$fullName[n]

			thisMatrixName = sub(".*\\.([^\\.]*)\\[.*", replacement = "\\1", x = fullName) # .matrix[
			thisMatrixRow  = as.numeric(sub(".*\\[(.*),(.*)\\]", replacement = "\\1", x = fullName))
			thisMatrixCol  = as.numeric(sub(".*\\[(.*),(.*)\\]", replacement = "\\2", x = fullName))
			CIparts = round(CIlist[n, c("estimate", "lbound", "ubound")], 2)
			thisString = paste(CIparts[1], " [",CIparts[2], ", ",CIparts[3], "]", sep="")
			# print(list(CIlist, labelList, rowCount, fullName, thisMatrixName))

			if(grepl("^a", thisMatrixName)) {
				a_std[thisMatrixRow, thisMatrixCol] = thisString
			} else if(grepl("^c", thisMatrixName)){
				c_std[thisMatrixRow, thisMatrixCol] = thisString
			} else if(grepl("^e", thisMatrixName)){
				e_std[thisMatrixRow, thisMatrixCol] = thisString
			} else{
				stop(paste("Illegal matrix name: must begin with a, c, or e. You sent: ", thisMatrixName))
			}
		}
		print(a_std)
		print(c_std)
		print(e_std)
	}
	} # Use CIs
	stdFit$top$a$values = a_std
	stdFit$top$c$values = c_std
	stdFit$top$e$values = e_std
	if(!is.na(file)) {
		message("making dot file")
		plot(model, file, std = std)
	}
	if(returnStd) {
		if(CIs){
			message("Returned model won't work if you asked for CIs...")
		}
		return(stdFit)
	}
}
#' @export
umxSummary.MxModelACEcov <- umxSummaryACEcov


#' Present the results of a Common-pathway twin model in table and graphical form
#'
#' Summarizes a Common-Pathway model, as returned by \code{\link{umxCP}}
#'
#' @aliases umxSummary.MxModelCP
#' @param model A fitted \code{\link{umxCP}} model to summarize
#' @param digits Round to how many digits (default = 2)
#' @param std Whether to show the standardized model (TRUE) (ignored: used extended = TRUE to get unstandardized)
#' @param CIs Confidence intervals (default FALSE)
#' @param showRg Whether to show the genetic correlations (default FALSE)
#' @param comparison Run mxCompare on a comparison model (default NULL)
#' @param report Print tables to the console (as 'markdown'), or open in browser ('html')
#' @param file The name of the dot file to write: NA = none; "name" = use the name of the model
#' @param returnStd Whether to return the standardized form of the model (default = FALSE)
#' @param ... Optional additional parameters
#' @return - optional \code{\link{mxModel}}
#' @export
#' @family Twin Modeling Functions
#' @seealso - \code{\link{umxCP}()}, \code{\link{plot}()}, \code{\link{umxSummary}()} work for IP, CP, GxE, SAT, and ACE models.
#' @references - \url{https://www.github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' \dontrun{
#' require(umx)
#' umx_set_optimizer("SLSQP")
#' data(twinData)
# # Help optimizer by putting wt on a similar scale to ht
#' twinData$wt1 = twinData$wt1/10
#' twinData$wt2 = twinData$wt2/10
#' selDVs = c("ht", "wt")
#' mzData <- subset(twinData, zygosity == "MZFF")
#' dzData <- subset(twinData, zygosity == "DZFF")
#' umx_set_auto_plot(FALSE) # turn off autoplotting for CRAN
#' m1 = umxCP(selDVs = selDVs, dzData = dzData, mzData = mzData, sep = "", optimizer = "SLSQP")
#' umxSummaryCP(m1, file = NA) # Suppress plot creation with file
#' umxSummary(m1, file = NA)   # Generic summary is the same
#' stdFit = umxSummaryCP(m1, digits = 2, std = TRUE, file = NA, returnStd = TRUE);
#' umxSummary(m1, std = FALSE, showRg = TRUE, file = NA);
#' umxSummary(m1, std = FALSE, file = NA)
#' # =================
#' # = Print example =
#' # =================
#' umxSummary(m1, file = "Figure 3", std = TRUE)
#' # =================
#' # = Confint example =
#' # =================
#' m1 = umxConfint(m1, "smart", run = FALSE);
#' m1 = umxConfint(m1, "smart", run = TRUE);
#' umxSummary(m1, CIs = TRUE, file = NA);
#' }
#'
umxSummaryCP <- function(model, digits = 2, std = TRUE, CIs = FALSE, showRg = FALSE, comparison = NULL, report = c("markdown", "html"), file = getOption("umx_auto_plot"), returnStd = FALSE,...) {
	report = match.arg(report)
	# TODO: Detect value of DZ covariance, and if .25 set "C" to "D" in tables

	if(typeof(model) == "list"){ # call self recursively
		for(thisFit in model) {
			message(paste("Output for Model: ", thisFit$name))
			umxSummaryCP(thisFit, digits = digits, file = file, returnStd = returnStd, showRg = showRg, comparison = comparison, std = std, CIs = CIs)
		}
	} else {
		umx_check_model(model, "MxModelCP", beenRun = TRUE, callingFn = "umxSummaryCP")
		umx_show_fit_or_comparison(model, comparison = comparison, digits = digits)
		selDVs = dimnames(model$top.expCovMZ)[[1]]
		nVar   = length(selDVs)/2
		nFac   = dim(model$top$matrices$a_cp)[[1]]	

		if(CIs){
			oldModel = model # Cache this in case we need it (CI stash model has string where values should be).
			model = umx_stash_CIs(model, digits = digits, dropZeros = TRUE, stdAlg2mat = TRUE)
		} else if(any(c(std, returnStd))) {
			model = umx_standardize_CP(model) # Make a standardized copy of model
		}

		message("## Common Factor paths")
		a_cp = model$top$a_cp$values # nFac * nFac matrix of path coefficients flowing into cp_loadings
		c_cp = model$top$c_cp$values
		e_cp = model$top$e_cp$values

		# Common factor ACE inputs are std to 1
		# Bind diags of a_cp, c and e columns into nFac-row matrix
		commonACE = cbind(diag(a_cp), diag(c_cp), diag(e_cp)) 
		commonACE = data.frame(commonACE, row.names = paste("Common.factor", 1:nFac, sep = "."), stringsAsFactors = FALSE);
		names(commonACE) = c ("A", "C", "E")
		if(report == "html"){
			umx_print(commonACE, digits = digits, zero.print = ".", file = "std_spec.html")
		} else {
			umx_print(commonACE, digits = digits, zero.print = ".")
		}
		
		if(class(model$top$matrices$a_cp)[1] == "LowerMatrix"){
			message("You used correlated genetic inputs to the common factor. This is the a_cp matrix")
			print(a_cp)
		}
		
		message("## Loading of each trait on the Common Factors")
		# Get standardized loadings on Common factors
		rowNames = sub("(_T)?1$", "", selDVs[1:nVar]) # Clean up names
		cp_loadings = model$top$cp_loadings$values # nVar * nFac matrix
		cp_loadings = data.frame(cp_loadings, row.names = rowNames, stringsAsFactors = FALSE);
		names(cp_loadings) = paste0("CP", 1:length(names(cp_loadings)))
		if(report == "html"){
			umx_print(cp_loadings, digits = digits, zero.print = ".", file = "std_common.html");
		} else {
			umx_print(cp_loadings, digits = digits, zero.print = ".")
		}

		message("## Specific-factor loadings")
		# Specific path coefficients ready to be stacked together
		as = model$top$as$values # Specific factor path coefficients
		cs = model$top$cs$values
		es = model$top$es$values

		specifics = data.frame(row.names = paste0('Specific ', c('a', 'c', 'e')), stringsAsFactors = FALSE,
			rbind(diag(as), 
				  diag(cs),
				  diag(es))
		)
		names(specifics) = rowNames;

		if(report == "html"){
			umx_print(specifics, digits = digits, zero.print = ".", file = "std_spec.html")
		} else {
			umx_print(specifics, digits = digits, zero.print = ".")
		}
		
		if(showRg) {
			message("Genetic Correlations")
			# Pre & post multiply covariance matrix by inverse of standard deviations
			A  = model$top$A$values # Variances
			C  = model$top$C$values
			E  = model$top$E$values
			Vtot = A + C + E; # Total variance
			nVarIden = diag(nVar)
			NAmatrix <- matrix(NA, nVar, nVar);

			rA = tryCatch(solve(sqrt(nVarIden * A)) %*% A %*% solve(sqrt(nVarIden * A)), error = function(err) return(NAmatrix)); # genetic correlations
			rC = tryCatch(solve(sqrt(nVarIden * C)) %*% C %*% solve(sqrt(nVarIden * C)), error = function(err) return(NAmatrix)); # C correlations
			rE = tryCatch(solve(sqrt(nVarIden * E)) %*% E %*% solve(sqrt(nVarIden * E)), error = function(err) return(NAmatrix)); # E correlations
			genetic_correlations = data.frame(cbind(rA, rC, rE), row.names = rowNames);
			# Make a table
			names(genetic_correlations) = paste0(rep(c("rA", "rC", "rE"), each = nVar), rep(1:nVar));
			if(report == "html"){
				umx_print(genetic_correlations, digits = digits, zero.print = ".", file = "geneticCorrs.html")
			} else {
				umx_print(genetic_correlations, digits = digits, zero.print = ".")
			}
			
		}
		if(!is.na(file)){
			umxPlotCP(model, file = file, digits = digits, std = FALSE, means = FALSE)
		}
		if(returnStd) {
			invisible(model)
		}
	}
}

#' @export
umxSummary.MxModelCP <- umxSummaryCP

#' Present the results of an independent-pathway twin model in table and graphical form
#'
#' Summarize a Independent Pathway model, as returned by \code{\link{umxIP}}
#'
#' @aliases umxSummary.MxModelIP
#' @param model A fitted \code{\link{umxIP}} model to summarize
#' @param digits round to how many digits (default = 2)
#' @param file The name of the dot file to write: NA = none; "name" = use the name of the model
#' @param returnStd Whether to return the standardized form of the model (default = FALSE)
#' @param showRg = whether to show the genetic correlations (FALSE)
#' @param std = Whether to show the standardized model (TRUE)
#' @param comparison Whether to run mxCompare on a comparison model (NULL)
#' @param CIs Confidence intervals (F)
#' @param ... Optional additional parameters
#' @return - optional \code{\link{mxModel}}
#' @family Twin Modeling Functions
#' @export
#' @seealso - \code{\link{umxIP}()}, \code{\link{plot}()}, \code{\link{umxSummary}()} work for IP, CP, GxE, SAT, and ACE models.
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' require(umx)
#' data(GFF) # family function and well-being data
#' mzData <- subset(GFF, zyg_2grp == "MZ")
#' dzData <- subset(GFF, zyg_2grp == "DZ")
#' selDVs = c("hap", "sat", "AD") # These will be expanded into "hap_T1" "hap_T2" etc.
#' m1 = umxIP(selDVs = selDVs, sep = "_T", dzData = dzData, mzData = mzData)
#' umxSummaryIP(m1)
#' plot(m1)
#' \dontrun{
#' umxSummaryIP(m1, digits = 2, file = "Figure3", showRg = FALSE, CIs = TRUE);
#' }
umxSummaryIP <- function(model, digits = 2, file = getOption("umx_auto_plot"), returnStd = FALSE, std = TRUE, showRg = FALSE, comparison = NULL, CIs = FALSE, ...) {
	umx_check_model(model, "MxModelIP", beenRun = TRUE, callingFn = "umxSummaryIP")
	umx_show_fit_or_comparison(model, comparison = comparison, digits = digits)

	selDVs = dimnames(model$top.expCovMZ)[[1]]
	stdFit = model; # If we want to output a model with the standardized values (perhaps for drawing a path diagram)
	nVar   = length(selDVs)/2;
	# how to detect how many factors are present?
	# Calculate standardized variance components
	ai = mxEval(top.ai, model); # Column of independent path coefficients (nVar * nFac) 
	ci = mxEval(top.ci, model);
	ei = mxEval(top.ei, model);

	as = mxEval(top.as, model); # nVar*nVar matrix of specific path coefficients (Just diagonal, or possibly Choleksy lower for E)
	cs = mxEval(top.cs, model);
	es = mxEval(top.es, model);

	A  = mxEval(top.A , model); # Totaled Variance components (ai + as etc.)
	C  = mxEval(top.C , model);
	E  = mxEval(top.E , model);

	nFac     = c(a = dim(ai)[2], c = dim(ci)[2], e = dim(ei)[2]);

	Vtot     = A+C+E; # total variance
	nVarIden = diag(nVar); # Make up a little nVar Identity matrix using the clever behavior of diag to make an nVar*nVar Identity matrix
	SD       = solve(sqrt(nVarIden*Vtot))   # inverse of diagonal matrix of standard deviations  (same as "(\sqrt(I.Vtot))~"
	ai_std   = SD %*% ai ; # Standardized path coefficients (independent general factors )
	ci_std   = SD %*% ci ; # Standardized path coefficients (independent general factors )
	ei_std   = SD %*% ei ; # Standardized path coefficients (independent general factors )

	stdFit@submodels$top$ai@values = ai_std
	stdFit@submodels$top$ci@values = ci_std
	stdFit@submodels$top$ei@values = ei_std

	rowNames = sub("(_T)?1$", "", selDVs[1:nVar])
	std_Estimates = data.frame(cbind(ai_std, ci_std, ei_std), row.names = rowNames, stringsAsFactors = FALSE);
	message("## General IP path loadings")
	x = sapply(FUN=seq_len, nFac)
	names(std_Estimates) = c(paste0("ai", 1:nFac["a"]), paste0("ci", 1:nFac["c"]), paste0("ei", 1:nFac["e"]))
	umx_print(std_Estimates, digits = digits, zero.print = ".")

	# Standard specific path coefficients ready to be stacked together
	as_std = SD %*% as; # Standardized path coefficients (nVar specific factors matrices)
	cs_std = SD %*% cs;
	es_std = SD %*% es;
	stdFit@submodels$top$as@values = as_std
	stdFit@submodels$top$cs@values = cs_std
	stdFit@submodels$top$es@values = es_std

	message("## Specific factor loadings")
	std_Specifics = data.frame(row.names = paste0('Specific ', c('a', 'c', 'e')),
		rbind(
			diag(as_std), 
			diag(cs_std),
			diag(es_std)
		)
	)
	names(std_Specifics) = rowNames;
	umx_print(round(std_Specifics, digits), digits = digits, zero.print = ".")

	if(showRg) {
		# Pre & post multiply covariance matrix by inverse of standard deviations
		NAmatrix <- matrix(NA, nVar, nVar);  
		rA = tryCatch(solve(sqrt(nVarIden*A)) %*% A %*% solve(sqrt(nVarIden*A)), error=function(err) return(NAmatrix)); # genetic correlations
		rC = tryCatch(solve(sqrt(nVarIden*C)) %*% C %*% solve(sqrt(nVarIden*C)), error=function(err) return(NAmatrix)); # shared environmental correlations
		rE = tryCatch(solve(sqrt(nVarIden*E)) %*% E %*% solve(sqrt(nVarIden*E)), error=function(err) return(NAmatrix)); # Unique environmental correlations
		genetic_correlations = data.frame(cbind(rA, rC, rE), row.names = rowNames);
		# Make a table
		names(genetic_correlations) = paste0(rep(c("rA", "rC", "rE"), each = nVar), rep(1:nVar));
		umx_print(genetic_correlations, digits = digits, zero.print = ".")
	}
	if(CIs){
		message("Showing CIs in output not implemented yet. In the mean time, use summary(model) to view them.")
	}
	if(!is.na(file)){
		umxPlotIP(x = stdFit, file = file, digits = digits, std = FALSE)
	}
	if(returnStd) {
		return(stdFit)
	}
}

#' @export
umxSummary.MxModelIP <- umxSummaryIP

#' umxSummaryGxE
#'
#' Summarize a Moderation model, as returned by \code{\link{umxGxE}}
#'
#' @aliases umxSummary.MxModelGxE
#' @param model A fitted \code{\link{umxGxE}} model to summarize
#' @param digits round to how many digits (default = 2)
#' @param file The name of the dot file to write: NA = none; "name" = use the name of the model
#' @param returnStd Whether to return the standardized form of the model (default = FALSE)
#' @param std Whether to show the standardized model (not implemented! TRUE)
#' @param CIs Confidence intervals (FALSE)
#' @param xlab label for the x-axis of plot
#' @param location default = "topleft"
#' @param reduce  Whether run and tabulate a complete model reduction...(Defaults to FALSE)
#' @param separateGraphs default = F
#' @param report "1" = regular, "2" = add descriptive sentences; "html" = open a browser and copyable tables
#' @param ... Optional additional parameters
#' @return - optional \code{\link{mxModel}}
#' @family Twin Modeling Functions
#' @export
#' @seealso - \code{\link{umxGxE}()}, \code{\link{plot}()}, \code{\link{umxSummary}()} work for IP, CP, GxE, and ACE models.
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' # The total sample has been subdivided into a young cohort, 
#' # aged 18-30 years, and an older cohort aged 31 and above.
#' # Cohort 1 Zygosity is coded as follows 1 == MZ females 2 == MZ males 
#' # 3 == DZ females 4 == DZ males 5 == DZ opposite sex pairs
#  # use ?twinData to learn about this data set.
#' require(umx)
#' data(twinData) 
#' twinData$age1 = twinData$age2 = twinData$age
#' selDVs  = c("bmi1", "bmi2")
#' selDefs = c("age1", "age2")
#' selVars = c(selDVs, selDefs)
#' mzData  = subset(twinData, zygosity == "MZFF", selVars)
#' dzData  = subset(twinData, zygosity == "DZMM", selVars)
#' # Exclude cases with missing Def
#' mzData <- mzData[!is.na(mzData[selDefs[1]]) & !is.na(mzData[selDefs[2]]),]
#' dzData <- dzData[!is.na(dzData[selDefs[1]]) & !is.na(dzData[selDefs[2]]),]
#' \dontrun{
#' m1 = umxGxE(selDVs = selDVs, selDefs = selDefs, dzData = dzData, mzData = mzData)
#' # Plot Moderation
#' umxSummaryGxE(m1)
#' umxSummaryGxE(m1, location = "topright")
#' umxSummaryGxE(m1, separateGraphs = FALSE)
#' }
umxSummaryGxE <- function(model = NULL, digits = 2, xlab = NA, location = "topleft", separateGraphs = FALSE, file = getOption("umx_auto_plot"), returnStd = NULL, std = NULL, reduce = FALSE, CIs = NULL, report = c("markdown", "html"), ...) {
	report = match.arg(report)
	umx_has_been_run(model, stop = TRUE)
	
	if(any(!is.null(c(returnStd, std, CIs) ))){
		message("For GxE, returnStd, std, comparison or CIs are not yet implemented...")
	}

	if(is.null(model)){
		message("umxSummaryGxE calls plot.MxModelGxE for a twin moderation plot. A use example is:\n umxSummaryGxE(model, location = \"topright\")")
		stop();
	}
	umxPlotGxE(model, xlab = xlab, location = location, separateGraphs = separateGraphs)

	if(reduce){
		umxReduce(model = model, report = report)
	}
}

#' @export
umxSummary.MxModelGxE <- umxSummaryGxE


#' Print a comparison table of one or more \code{\link{mxModel}}s, formatted nicely.
#'
#' @description
#' umxCompare compares two or more \code{\link{mxModel}}s. It has several nice features:
#' 
#' 1. It supports direct control of rounding, and reports p-values rounded to APA style.
#' 
#' 2. It reports the table in your preferred format (default is markdown, options include latex)
#' 
#' 3. Table columns are arranged to make for easy comparison for readers.
#' 
#' 4. report = 'inline', will provide an English sentence suitable for a paper.
#' 
#' 5. report = "html" opens a web table in your browser to paste into a word processor.
#' 
#' \emph{Note}: If you leave comparison blank, it will just give fit info for the base model
#'
#' @param base The base \code{\link{mxModel}} for comparison
#' @param comparison The model (or list of models) which will be compared for fit with the base model (can be empty)
#' @param all Whether to make all possible comparisons if there is more than one base model (defaults to T)
#' @param digits rounding for p-values etc.
#' @param report "markdown" (default), "inline" (a sentence suitable for inclusion in a paper), or "html".
#' create a web table and open your default browser.
#' (handy for getting tables into Word, and other text systems!)
#' @param file file to write html too if report = "html" (defaults to "tmp.html")
#' @param compareWeightedAIC Show the Wagenmakers AIC weighted comparison (default = FALSE)
#' @family Reporting functions
#' @seealso - \code{\link{mxCompare}}, \code{\link{umxSummary}}, \code{\link{umxRAM}},
#' @references - \url{https://www.github.com/tbates/umx/}
#' @export
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' m2 = umxModify(m1, update = "G_to_x2", name = "drop_path_2_x2")
#' umxCompare(m1, m2)
#' umxCompare(m1, m2, report = "report") # Add English-sentence descriptions
#' \dontrun{
#' umxCompare(m1, m2, report = "html") # Open table in browser
#' }
#' m3 = umxModify(m2, update = "G_to_x3", name = "drop_path_2_x2_and_3")
#' umxCompare(m1, c(m2, m3))
#' umxCompare(m1, c(m2, m3), compareWeightedAIC = TRUE)
#' umxCompare(c(m1, m2), c(m2, m3), all = TRUE)
umxCompare <- function(base = NULL, comparison = NULL, all = TRUE, digits = 3, report = c("markdown", "inline", "html", "report"), compareWeightedAIC = FALSE, file = "tmp.html") {
	report = match.arg(report)
	if(	report == "report"){
		message("inline-style report is being renamed to 'inline' instead of 'report'. Please change this for the future")
		report = "inline"
	}
	if(is.null(comparison)){
		comparison <- base
	} else if (is.null(base)) {
		stop("You must provide at least a base model for umxCompare")
	}
	if(length(base) == 1) {
		if(typeof(base) == "list"){
			base = base[[1]]
		}
		if(!umx_has_been_run(base)){
			warning("base model not run yet!")		
		}
	}
	if(length(comparison) == 1) {
		if(typeof(comparison) == "list"){
			comparison = comparison[[1]]
		}
		if(!umx_has_been_run(comparison)){
			warning("Comparison model has not been run!")		
		}
	}
	tableOut = mxCompare(base = base, comparison = comparison, all = all)

	# | 1       |    2          | 3  | 4        | 5   | 6        | 7        | 8      | 9    |
	# | base    | comparison    | ep | minus2LL | df  | AIC      | diffLL   | diffdf | p    |
	# | twinSat | <NA>          | 13 | 333.0781 | 149 | 35.07809 | NA       | NA     | NA   |
	# | twinSat | betaSetToZero | 10 | 351.6486 | 152 | 47.64858 | 18.57049 | 3      | 0.01 |

	tablePub = tableOut[, c("comparison", "ep", "diffLL"      , "diffdf"    , "p", "AIC", "base")]
	# names(tablePub)   <- c("Model"     , "EP", "&Delta; -2LL", "&Delta; df", "p", "AIC", "Compare with Model")
	names(tablePub)     <- c("Model"     , "EP", "\u2206 -2LL", "\u2206 df", "p", "AIC", "Compare with Model")
	# U+2206 = math delta
	# Fix problem where base model has compare set to its own name, and name set to NA
	nRows = dim(tablePub)[1]
	for (i in 1:nRows) {
		if(is.na(tablePub[i, "Model"])){
			tablePub[i, "Model"] = tablePub[i, "Compare with Model"] 
			tablePub[i, "Compare with Model"] = NA
		}
	}
	tablePub[,"p"] = umx_APA_pval(tablePub[, "p"], min = (1/ 10^3), digits = digits, addComparison = NA)
	# c("1: Comparison", "2: Base", "3: EP", "4: AIC", "5: &Delta; -2LL", "6: &Delta; df", "7: p")
	if(report == "inline"){
		n_rows = dim(tablePub)[1]
		for (i in 1:n_rows) {
			thisPValue = tableOut[i, 9]
			if(!is.na(thisPValue) && !is.nan(thisPValue)){
				if(tableOut[i, 9] < .05){
					did_didnot = ". This caused a significant loss of fit "
				} else {
					did_didnot = ". This did not lower fit significantly "
				}
				message(
				"The hypothesis that ", tablePub[i,"Model"], 
				" was tested by dropping ", tablePub[i,"Model"],
				" from ", tablePub[i,"Compare with Model"], 
				did_didnot, 
				"(\u03C7\u00B2(", tablePub[i, 4], ") = ", round(tablePub[i, 3], 2), # \u03A7 = Chi \u00B2 = superscript 2
				", p = ", tablePub[i,"p"], ": AIC = ", round(tablePub[i,"AIC"], digits), ")."
				)
			}
		}
	}
	
	if(report == "html"){
		tableHTML = tablePub
		names(tableHTML) <- c("Model", "EP", "&Delta; -2LL", "&Delta; df", "p", "AIC", "Compare with Model")
		print(xtable::xtable(tableHTML), type = "HTML", file = file, sanitize.text.function = function(x){x})
		# digitList         =  c(0       , 0   , 3             ,  3          , 3  ,  3    , 0)
		# nsmallList        =  c(0       , 0   , 3             ,  3          , 3  ,  3    , 0)
		# R2HTML::HTML(tableHTML, file = file, Border = 0, append = FALSE, sortableDF = TRUE, digits = digitList)# , nsmall = nsmallList);
		umx_open(file)
	} else {
		umx_print(tablePub)
	}
	if(compareWeightedAIC){
		modelList = c(base, comparison)
		# get list of AICs
		AIClist = c()
		for (i in modelList) {
			AIClist = c(AIClist, AIC(i))
		}
		whichBest = which.min(AIClist)
		bestModel = modelList[[whichBest]]
		message("The ", omxQuotes(bestModel$name), " model is the best fitting model according to AIC.")
		# Probabilities according to AIC MuMIn::Weights (Wagenmakers et al https://www.ncbi.nlm.nih.gov/pubmed/15117008 )
		aic.weights = round(Weights(AIClist), 2)
		message("AIC weight-based  {Wagenmakers, 2004, 192-196} conditional probabilities of being the best model for ", 
			omxQuotes(namez(modelList)), " respectively are: ", 
			omxQuotes(aic.weights), " Using MuMIn::Weights(AIC()).")	
	}
	invisible(tablePub)
}

#' umxCI_boot
#'
#' Compute boot-strapped Confidence Intervals for parameters in an \code{\link{mxModel}}
#' The function creates a sampling distribution for parameters by repeatedly drawing samples
#' with replacement from your data and then computing the statistic for each redrawn sample.
#' @param model is an optimized mxModel
#' @param rawData is the raw data matrix used to estimate model
#' @param type is the kind of bootstrap you want to run. "par.expected" and "par.observed" 
#' use parametric Monte Carlo bootstrapping based on your expected and observed covariance matrices, respectively.
#' "empirical" uses empirical bootstrapping based on rawData.
#' @param std specifies whether you want CIs for unstandardized or standardized parameters (default: std = TRUE)
#' @param rep is the number of bootstrap samples to compute (default = 1000).
#' @param conf is the confidence value (default = 95)
#' @param dat specifies whether you want to store the bootstrapped data in the output (useful for multiple analyses, such as mediation analysis)
#' @param digits rounding precision
#' @return - expected covariance matrix
#' @export
#' @examples
#' \dontrun{
#' 	require(umx)
#' 	data(demoOneFactor)
#' 	latents  = c("G")
#' 	manifests = names(demoOneFactor)
#' 	m1 <- mxModel("One Factor", type = "RAM", 
#' 		manifestVars = manifests, latentVars = latents, 
#' 		mxPath(from = latents, to = manifests),
#' 		mxPath(from = manifests, arrows = 2),
#' 		mxPath(from = latents, arrows = 2, free = FALSE, values = 1.0),
#' 		mxData(cov(demoOneFactor), type = "cov", numObs = 500)
#' 	)
#' 	m1 = umxRun(m1, setLabels = TRUE, setValues = TRUE)
#' 	umxCI_boot(m1, type = "par.expected")
#'}
#' @references - \url{https://openmx.ssri.psu.edu/thread/2598}
#' Original written by \url{https://openmx.ssri.psu.edu/users/bwiernik}
#' @seealso - \code{\link{umxExpMeans}}, \code{\link{umxExpCov}}
#' @family Reporting functions
umxCI_boot <- function(model, rawData = NULL, type = c("par.expected", "par.observed", "empirical"), std = TRUE, rep = 1000, conf = 95, dat = FALSE, digits = 3) {
	# depemds on MASS::mvrnorm
	type = umx_default_option(type, c("par.expected", "par.observed", "empirical"))
	if(type == "par.expected") {
		exp = umxExpCov(model, latents = FALSE)
	} else if(type == "par.observed") {
		if(model$data$type == "raw") {
			exp = var(mxEval(data, model))
		} else { 
			if(model$data$type == "sscp") {
				exp = mxEval(data, model) / (model$data$numObs - 1)
			} else {
				exp = mxEval(data, model)
			}
		}
	}
	N = round(model$data$numObs)
	pard = t(data.frame("mod" = summary(model)$parameters[, 5 + 2 * std], row.names = summary(model)$parameters[, 1]))
	pb   = txtProgressBar(min = 0, max = rep, label = "Computing confidence intervals", style = 3)
	#####
	if(type == "empirical") {
		if(length(rawData) == 0) {
			if(model$data$type == "raw"){
				rawData = mxEval(data, model)
			} else {
				stop("No raw data supplied for empirical bootstrap.")	
			}
		}
		for(i in 1:rep){
			bsample.i = sample.int(N, size = N, replace = TRUE)
			bsample   = var(rawData[bsample.i, ])
			mod       = mxRun(mxModel(model, mxData(observed = bsample, type = "cov", numObs = N)), silent = TRUE)
			pard      = rbind(pard, summary(mod)$parameters[, 5 + 2*std])
			rownames(pard)[nrow(pard)] = i
			utils::setTxtProgressBar(pb, i)
		}
	} else {
		for(i in 1:rep){
			bsample = var(MASS::mvrnorm(N, rep(0, nrow(exp)), exp))
			mod     = mxRun(mxModel(model, mxData(observed = bsample, type = "cov", numObs = N)), silent = TRUE)
			pard    = rbind(pard, summary(mod)$parameters[, 5 + 2 * std])
			rownames(pard)[nrow(pard)] = i
			utils::setTxtProgressBar(pb, i)
		}
	}
	low = (1-conf/100)/2
	upp = ((1-conf/100)/2) + (conf/100)
	LL  = apply(pard, 2, FUN = quantile, probs = low) #lower limit of confidence interval
	UL  = apply(pard, 2, FUN = quantile, probs = upp) #upper quantile for confidence interval
	LL4 = round(LL, 4)
	UL4 = round(UL, 4)
	ci  = cbind(LL4, UL4)
	colnames(ci) = c(paste((low*100), "%", sep = ""), paste((upp*100), "%", sep = ""))
	p = summary(model)$parameters[, c(1, 2, 3, 4, c(5:6 + 2*std))]
	cols <- sapply(p, is.numeric)
	p[, cols] <- round(p[,cols], digits) 
	
	if(dat) {
		return(list("Type" = type, "bootdat" = data.frame(pard), "CI" = cbind(p, ci)))
	} else {
		return(list("CI" = cbind(p, ci)))
	}
}


# ============
# = Graphics =
# ============

#' Create and display a graphical path diagram for a model.
#'
#' plot() produces SEM diagrams in graphviz format, and relies on \code{\link{DiagrammeR}} (or a 
#' graphviz application) to create the image. 
#' The commercial application \dQuote{OmniGraffle} is great for editing these images.
#' 
#'
#' On unix and windows, \code{\link{plot}}() will create a pdf and open it in your default pdf reader.
#' 
#' \emph{Note:} DiagrammeR is supported out of the box.  By default, plots open in your browser. 
#' 
#' If you use umx_set_plot_format("graphviz"), they will open in a graphviz helper app (if installed).
#' If you use graphviz, we try and use that app, but YOU HAVE TO INSTALL IT!
#' On OS X we try and open an app: you may need to associate the \sQuote{.gv}
#' extension with the graphviz app.
#' Find the .gv file made by plot, get info (cmd-I), then choose \dQuote{open with}, 
#' select graphviz.app (or OmniGraffle professional),
#' then set \dQuote{change all}.
#'
#' @aliases plot umxPlot
#' @rdname plot.MxModel
#' @param x An \code{\link{mxModel}} from which to make a path diagram
#' @param std Whether to standardize the model (default = FALSE).
#' @param fixed Whether to show fixed paths (defaults to TRUE)
#' @param means Whether to show means or not (default = TRUE)
#' @param digits The number of decimal places to add to the path coefficients
#' @param file The name of the dot file to write: NA = none; "name" = use the name of the model
#' @param pathLabels Whether to show labels on the paths. both will show both the parameter and the label. ("both", "none" or "labels")
#' @param resid How to show residuals and variances default is "circle". Options are "line" & "none"
#' @param strip_zero Whether to strip the leading "0" and decimal point from parameter estimates (default = TRUE)
#' @param ... Optional parameters
#' @export
#' @seealso - \code{\link{umx_set_plot_format}}, \code{\link{plot.MxModel}}, \code{\link{umxPlotACE}}, \code{\link{umxPlotCP}}, \code{\link{umxPlotIP}}, \code{\link{umxPlotGxE}}
#' @family Core Modeling Functions
#' @family Plotting functions
#' @references - \url{https://www.github.com/tbates/umx}, \url{https://en.wikipedia.org/wiki/DOT_(graph_description_language)}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' plot(m1)
#' plot(m1, std = TRUE, resid = "line", digits = 3, strip_zero = FALSE)
plot.MxModel <- function(x = NA, std = FALSE, fixed = TRUE, means = TRUE, digits = 2, file = "name", pathLabels = c("none", "labels", "both"), resid = c("circle", "line", "none"), strip_zero = TRUE, ...) {
	# ==========
	# = Setup  =
	# ==========
	resid = match.arg(resid)
	model = x # just to be clear that x is a model

	pathLabels = match.arg(pathLabels)
	latents = model@latentVars   # 'vis', 'math', and 'text' 
	selDVs  = model@manifestVars # 'visual', 'cubes', 'paper', 'general', 'paragrap'...
	
	# update values using compute = T to capture labels with [] references.
	# TODO: !!! Needs more work to sync with confidence intervals and SES
	model$S$values = mxEval(S, model, compute = T)
	model$A$values = mxEval(A, model, compute = T)
	if(!is.null(model$M)){
		model$M$values = mxEval(M, model, compute = T)
	}
	
	if(std){ model = umx_standardize_RAM(model, return = "model") }

	# ========================
	# = Get Symmetric & Asymmetric Paths =
	# ========================
	out = "";
	out = xmu_dot_make_paths(model$matrices$A, stringIn = out, heads = 1, fixed = fixed, pathLabels = pathLabels, comment = "Single arrow paths", digits = digits)
	if(resid == "circle"){
		out = xmu_dot_make_paths(model$matrices$S, stringIn = out, heads = 2, showResiduals = FALSE, fixed = fixed, pathLabels = pathLabels, comment = "Covariances", digits = digits)
	} else if(resid == "line"){
		out = xmu_dot_make_paths(model$matrices$S, stringIn = out, heads = 2, showResiduals = TRUE , fixed = fixed, pathLabels = pathLabels, comment = "Covariances & residuals", digits = digits)
	}else{
		out = xmu_dot_make_paths(model$matrices$S, stringIn = out, heads = 2, showResiduals = FALSE , fixed = fixed, pathLabels = pathLabels, comment = "Covariances & residuals", digits = digits)		
	}
	# TODO should xmu_dot_make_residuals handle fixed or not necessary?
	tmp = xmu_dot_make_residuals(model$matrices$S, latents = latents, digits = digits, resid = resid)
	variances     = tmp$variances  #either "var_var textbox" or "var -> var port circles"
	varianceNames = tmp$varianceNames # names of residuals/variances. EMPTY if using circles 
	# ============================
	# = Make the manifest shapes =
	# ============================
	preOut = "\t# Latents\n"
	for(var in latents) {
	   preOut = paste0(preOut, "\t", var, " [shape = circle];\n")
	}

	preOut = paste0(preOut, "\n\t# Manifests\n")
	for(var in selDVs) {
	   preOut = paste0(preOut, "\t", var, " [shape = square];\n")
	}

	
	# ================
	# = handle means =
	# ================
	if(umx_has_means(model) & means){
		out = paste0(out, "\n\t# Means paths\n")
		# Add a triangle to the list of shapes
		preOut = paste0(preOut, "\t one [shape = triangle];\n")
		mxMat = model$matrices$M
		mxMat_vals   = mxMat$values
		mxMat_free   = mxMat$free
		mxMat_labels = mxMat$labels
		meanVars = colnames(mxMat$values)
		for(to in meanVars) {
			thisPathLabel = mxMat_labels[1, to]
			thisPathFree  = mxMat_free[1, to]
			thisPathVal   = round(mxMat_vals[1, to], digits)
			if(thisPathFree){
				labelStart = ' [label="' 
			} else {
				labelStart = ' [label="@'
			}

			# TODO find a way of showing means fixed at zero?
			if(thisPathFree || fixed ) {
				# if(thisPathFree | (fixed & thisPathVal != 0) ) {
				out = paste0(out, "\tone -> ", to, labelStart, thisPathVal, '"];\n')
			}else{
				# cat(paste0(out, "\tone -> ", to, labelStart, thisPathVal, '"];\n'))
				# return(thisPathVal != 0)
			}
		}
	}

	# ===========================
	# = Make the variance lines =
	# ===========================
	# x1_var [label="0.21", shape = plaintext];
	# or (circles)
	# x1 -> x1 [label="0.21", direction = both];
	preOut = paste0(preOut, "\n\t#Variances/residuals\n")
	for(var in variances) {
	   preOut = paste0(preOut, "\t", var, ";\n")
	}
	# ======================
	# = Set the ranks e.g. =
	# ======================
	# {rank=same; x1 x2 x3 x4 x5 };
	# TODO more intelligence possible in plot() perhaps hints like "MIMIC" or "ACE"
	rankVariables = paste0("\t{rank=min ; ", paste(latents, collapse = "; "), "};\n")
	rankVariables = paste0(rankVariables, "\t{rank=same; ", paste(selDVs, collapse = " "), "};\n")
	if(umx_has_means(model)){ append(varianceNames, "one")}
	if(length(varianceNames) > 0){
		rankVariables = paste0(rankVariables, "\t{rank=max ; ", paste(varianceNames, collapse = " "), "};\n")
	}
	# ===================================
	# = Assemble full text to write out =
	# ===================================
	digraph = paste("digraph G {\n", preOut, out, rankVariables, "\n}", sep = "\n");
	print("?plot.MxModel options: std, digits, file, fixed, means, resid= 'circle|line|none' & more")
	xmu_dot_maker(model, file, digraph, strip_zero = strip_zero)
} # end plot.MxModel

#' umxPlotACE
#'
#' Make a graphical display of an ACE model
#'
#' @aliases plot.MxModelACE
#' @param x \code{\link{mxModel}} to plot (created by umxACE in order to inherit the MxModelACE class)
#' @param file The name of the dot file to write: NA = none; "name" = use the name of the model
#' @param digits How many decimals to include in path loadings (default is 2)
#' @param means Whether to show means paths (default is FALSE)
#' @param std Whether to standardize the model (default is TRUE)
#' @param strip_zero Whether to strip the leading "0" and decimal point from parameter estimates (default = TRUE)
#' @param ... Additional (optional) parameters
#' @return - optionally return the dot code
#' @export
#' @family Plotting functions
#' @seealso - \code{\link{plot}()}, \code{\link{umxSummary}()} work for IP, CP, GxE, SAT, and ACE models.
#' @seealso - \code{\link{umxACE}}
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(twinData)
#' selDVs = "bmi"
#' mzData <- subset(twinData, zygosity == "MZFF")
#' dzData <- subset(twinData, zygosity == "DZFF")
#' m1 = umxACE(selDVs = selDVs, dzData = dzData, mzData = mzData, sep = "")
#' plot(m1, std = FALSE) # don't standardize
umxPlotACE <- function(x = NA, file = "name", digits = 2, means = FALSE, std = TRUE, strip_zero = TRUE, ...) {
	if(!class(x) == "MxModelACE"){
		stop("The first parameter of umxPlotACE must be an ACE model, you gave me a ", class(x))
	}
	model = x # just to be clear that x is a model
	if(std){
		model = umx_standardize_ACE(model)
	}
	out = "";
	latents = c();
	if(model$MZ$data$type == "raw"){
		selDVs = names(model$MZ$data$observed)
	}else{
		selDVs = dimnames(model$MZ$data$observed)[[1]]
	}
	varCount = length(selDVs)/2;
	parameterKeyList = omxGetParameters(model);
	# TODO: Replace label-parsing with code that walks across the known matrices...
	# would obviate problems with arbitrary names.
	# 1. Could add dimnames() to A, C, E?
	
	for(thisParam in names(parameterKeyList) ) {
		value = parameterKeyList[thisParam]
		if(class(value) == "numeric") {
			value = round(value, digits)
		}
		# omxLocateParameters(model=model, labels=thisParam)

		if (grepl("^[ace]_r[0-9]+c[0-9]+", thisParam)) { # a c e
			from    = sub('([ace])_r([0-9]+)c([0-9]+)'           , '\\1\\3', thisParam, perl = TRUE);  # a c or e
			target  = as.numeric(sub('([ace])_r([0-9]+)c([0-9]+)', '\\2'   , thisParam, perl = TRUE));
			target  = selDVs[as.numeric(target)]
			latents = append(latents, from)
			show = TRUE
		} else { # means probably
			if(means){
				show = TRUE
			} else {
				show = FALSE
			}
			from   = thisParam;
			target = sub('r([0-9])c([0-9])', 'var\\2', thisParam, perl = TRUE) 
		}
		if(show){
			out = paste0(out, from, " -> ", target, " [label = \"", value, "\"]", ";\n")
		}
	}
	preOut = "\t# Latents\n"
	latents = unique(latents)
	for(var in latents) {
	   preOut = paste0(preOut, "\t", var, " [shape = circle];\n")
	}

	preOut = paste0(preOut, "\n\t# Manifests\n")
	for(var in selDVs[1:varCount]) {
	   preOut = paste0(preOut, "\t", var, " [shape = square];\n")
	}

	rankVariables = paste("\t{rank = same; ", paste(selDVs[1:varCount], collapse = "; "), "};\n") # {rank = same; v1T1; v2T1;}
	# grep('a', latents, value=T)
	rankA   = paste("\t{rank = min; ", paste(grep('a'   , latents, value=T), collapse="; "), "};\n") # {rank=min; a1; a2}
	rankCE  = paste("\t{rank = max; ", paste(grep('[ce]', latents, value=T), collapse="; "), "};\n") # {rank=min; c1; e1}
	digraph = paste0("digraph G {\n\tsplines = \"FALSE\";\n", preOut, out, rankVariables, rankA, rankCE, "\n}"); 
	xmu_dot_maker(model, file, digraph, strip_zero = strip_zero)
} # end umxPlotACE

#' @export
plot.MxModelACE <- umxPlotACE

#' Make a graphical display of an ACE model with covariates.
#'
#' Make a graphical display of an ACE model with covariates.
#'
#' @aliases plot.MxModelACEcov
#' @param x \code{\link{mxModel}} to plot (created by umxACE in order to inherit the MxModelACE class)
#' @param file The name of the dot file to write: NA = none; "name" = use the name of the model
#' @param digits How many decimals to include in path loadings (default is 2)
#' @param means Whether to show means paths (default is FALSE)
#' @param std Whether to standardize the model (default is TRUE)
#' @param strip_zero Whether to strip the leading "0" and decimal point from parameter estimates (default = TRUE) 
#' @param ... Additional (optional) parameters
#' @return - optionally return the dot code
#' @export
#' @family Plotting functions
#' @seealso - \code{\link{plot}()}, \code{\link{umxSummary}()} work for IP, CP, GxE, SAT, and ACE models.
#' @seealso - \code{\link{umxACE}}
#' @references - \url{https://tbates.github.io}
#' @examples
#' require(umx)
#' # BMI ?twinData from Australian twins. 
#' # Cohort 1 Zygosity 1 == MZ females 3 == DZ females
#' data(twinData)
#' # Pick the variables. We will use base names (i.e., "bmi") and set suffix.
#' selDVs  = c("bmi")
#' selCovs = c("ht")
#' selVars = umx_paste_names(c(selDVs, selCovs), sep = "", suffixes= 1:2)
#' # Just top few pairs so example runs quickly
#' mzData = subset(twinData, zygosity == "MZFF", selVars)[1:100, ]
#' dzData = subset(twinData, zygosity == "DZFF", selVars)[1:100, ]
#' m1 = umxACEcov(selDVs = selDVs, selCovs = selCovs, dzData = dzData, mzData = mzData, 
#' 	 sep = "", autoRun = TRUE)
#' plot(m1)
#' plot(m1, std = FALSE) # don't standardize
umxPlotACEcov <- function(x = NA, file = "name", digits = 2, means = FALSE, std = TRUE, strip_zero = TRUE, ...) {
	if(!class(x) == "MxModelACEcov"){
		stop("The first parameter of umxPlotACEcov must be an ACEcov model, you gave me a ", class(x))
	}
	model = x # just to be clear that x is a model
	# relies on 'a' not having its dimnames stripped off...
	if(model$MZ$data$type == "raw"){
		selDVs = dimnames(model$top$a)[[1]]
		# selDVs = names(model$MZ$data$observed)
	}else{
		stop("ACEcov has to have raw data...")
		# selDVs = dimnames(model$MZ$data$observed)[[1]]
	}
	if(std){
		model = umx_standardize_ACEcov(model)
	}
	out = "";
	latents = c();

	varCount = length(selDVs)
	parameterKeyList = omxGetParameters(model);
	for(thisParam in names(parameterKeyList) ) {
		value = parameterKeyList[thisParam]
		if(class(value) == "numeric") {
			value = round(value, digits)
		}
		if (grepl("^[ace]_r[0-9]+c[0-9]+", thisParam)) { # a c e
			show    = TRUE
			search  = '([ace])_r([0-9]+)c([0-9]+)'
			from    = sub(search, '\\1\\3', thisParam, perl = T); # a c or e
			target  = as.numeric(sub(search, '\\2', thisParam, perl = T)); # pull the row
			target  = selDVs[target]
			latents = append(latents, from)
		} else { # means probably
			if(means){
				show = TRUE
			} else {
				show = FALSE
			}
			selDVs
			from   = thisParam; # "one"
			target = sub('r([0-9])c([0-9])', 'var\\2', thisParam, perl=T)
		}
		if(show){
			out = paste0(out, from, " -> ", target, " [label = \"", value, "\"]", ";\n")
		}
	}
	preOut = "\t# Latents\n"
	latents = unique(latents)
	for(var in latents) {
	   preOut = paste0(preOut, "\t", var, " [shape = circle];\n")
	}

	preOut = paste0(preOut, "\n\t# Manifests\n")
	for(var in selDVs[1:varCount]) {
	   preOut = paste0(preOut, "\t", var, " [shape = square];\n")
	}
	rankVariables = paste("\t{rank = same; ", paste(selDVs[1:varCount], collapse = "; "), "};\n") # {rank = same; v1T1; v2T1;}
	# grep('a', latents, value=T)
	rankA   = paste("\t{rank = min; ", paste(grep('a'   , latents, value = T), collapse = "; "), "};\n") # {rank=min; a1; a2}
	rankCE  = paste("\t{rank = max; ", paste(grep('[ce]', latents, value = T), collapse = "; "), "};\n") # {rank=min; c1; e1}
	digraph = paste("digraph G {\n\tsplines = \"FALSE\";\n", preOut, out, rankVariables, rankA, rankCE, "\n}", sep="");
	xmu_dot_maker(model, file, digraph, strip_zero = strip_zero)
} # end umxPlotACEcov

#' @export
plot.MxModelACEcov <- umxPlotACEcov

#' Plot the results of a GxE univariate test for moderation of ACE components.
#'
#' Plot GxE results (univariate environmental moderation of ACE components).
#' Options include plotting the raw and standardized graphs separately, or in a combined panel.
#' You can also set the label for the x axis (xlab), and choose the location of the legend.
#'
#' @aliases plot.MxModelGxE
#' @param x A fitted \code{\link{umxGxE}} model to plot
#' @param xlab String to use for the x label (default = NA, which will use the variable name)
#' @param location Where to plot the legend (default = "topleft")
#' see ?legend for alternatives like bottomright
#' @param separateGraphs (default = FALSE)
#' @param acergb Colors to use for plot c(a = "red", c = "green", e = "blue", tot = "black")
#' @param ... Optional additional parameters
#' @return - 
#' @family Plotting functions
#' @export
#' @seealso - \code{\link{plot}()}, \code{\link{umxSummary}()} work for IP, CP, GxE, SAT, and ACE models.
#' @seealso - \code{\link{umxGxE}}
#' @references - \url{https://tbates.github.io}
#' @examples
#' require(umx)
#' data(twinData) 
#' twinData$age1 = twinData$age2 = twinData$age
#' selDVs  = "bmi"
#' selDefs = "age"
#' mzData  = subset(twinData, zygosity == "MZFF")
#' dzData  = subset(twinData, zygosity == "DZFF")
#' m1 = umxGxE(selDVs = selDVs, selDefs = selDefs, 
#'  	dzData = dzData, mzData = mzData, sep= "", dropMissing = TRUE)
#' plot(m1)
#' umxPlotGxE(x = m1, xlab = "SES", separateGraphs = TRUE, location = "topleft")
umxPlotGxE <- function(x, xlab = NA, location = "topleft", separateGraphs = FALSE, acergb = c("red", "green", "blue", "black"), ...) {
	if(!class(x) == "MxModelGxE"){
		stop("The first parameter of umxPlotGxE must be a GxE model, you gave me a ", class(x))
	}
	model = x # to remind us that x has to be a umxGxE model
	# get unique values of moderator
	mzData = model$MZ$data$observed
	dzData = model$DZ$data$observed
	selDefs = names(mzData)[3:4]
	if(is.na(xlab)){
		xlab = selDefs[1]
	}
	mz1 = as.vector(mzData[,selDefs[1]])
	mz2 = as.vector(mzData[,selDefs[2]])
	dz1 = as.vector(dzData[,selDefs[1]])
	dz2 = as.vector(dzData[,selDefs[2]])
	allValuesOfDefVar= c(mz1,mz2,dz1,dz2)
	defVarValues = sort(unique(allValuesOfDefVar))
	a   = model$top$matrices$a$values
	c   = model$top$matrices$c$values
	e   = model$top$matrices$e$values
	am  = model$top$matrices$am$values
	cm  = model$top$matrices$cm$values
	em  = model$top$matrices$em$values
	Va  = (c(a) + c(am) * defVarValues)^2
	Vc  = (c(c) + c(cm) * defVarValues)^2
	Ve  = (c(e) + c(em) * defVarValues)^2
	Vt  = Va + Vc + Ve
	out    = as.matrix(cbind(Va, Vc, Ve, Vt))
	outStd = as.matrix(cbind(Va/Vt, Vc/Vt, Ve/Vt))
	
	if(is.na(xlab)){
		xlab = sub("(_T)?[0-9]$", "", selDefs[1])
	}
	
	if(separateGraphs){
		print("Outputting two graphs")
	}else{
		graphics::par(mfrow = c(1, 2)) # one row, two columns for raw and std variance
		# par(mfrow = c(2, 1)) # two rows, one column for raw and std variance
	}
	# acergb = c("red", "green", "blue", "black")
	graphics::matplot(x = defVarValues, y = out, type = "l", lty = 1:4, col = acergb, xlab = xlab, ylab = "Variance", main= "Raw Moderation Effects")
	graphics::legend(location, legend = c("genetic", "shared", "unique", "total"), lty = 1:4, col = acergb)
	# legend(location, legend= c("Va", "Vc", "Ve", "Vt"), lty = 1:4, col = acergb)
	graphics::matplot(defVarValues, outStd, type = "l", lty = 1:4, col = acergb, ylim = 0:1, xlab = xlab, ylab = "Standardized Variance", main= "Standardized Moderation Effects")
	# legend(location, legend= c("Va", "Vc", "Ve"), lty = 1:4, col = acergb)
	graphics::legend(location, legend = c("genetic", "shared", "unique"), lty = 1:4, col = acergb)
	graphics::par(mfrow = c(1, 1)) # back to black
}

#' @export
plot.MxModelGxE <- umxPlotGxE

#' Draw and display a graphical figure of Common Pathway model
#'
#' Options include digits (rounding), showing means or not, and which output format is desired.
#'
#' @aliases plot.MxModelCP
#' @param x The Common Pathway \code{\link{mxModel}} to display graphically
#' @param file The name of the dot file to write: NA = none; "name" = use the name of the model
#' @param digits How many decimals to include in path loadings (defaults to 2)
#' @param means Whether to show means paths (defaults to FALSE)
#' @param std Whether to standardize the model (defaults to TRUE)
#' @param format = c("current", "graphviz", "DiagrammeR") 
#' @param SEstyle report "b (se)" instead of b CI95[l, u] (Default = FALSE)
#' @param strip_zero Whether to strip the leading "0" and decimal point from parameter estimates (default = TRUE)
#' @param ... Optional additional parameters
#' @return - Optionally return the dot code
#' @export
#' @seealso - \code{\link{plot}()}, \code{\link{umxSummary}()} work for IP, CP, GxE, SAT, and ACE models.
#' @seealso - \code{\link{umxCP}}
#' @family Plotting functions
#' @references - \url{https://tbates.github.io}
#' @examples
#' \dontrun{
#' plot(yourCP_Model) # no need to remember a special name: plot works fine!
#' }
umxPlotCP <- function(x = NA, file = "name", digits = 2, means = FALSE, std = TRUE,  format = c("current", "graphviz", "DiagrammeR"), SEstyle = FALSE, strip_zero = TRUE, ...) {
	if(!class(x) == "MxModelCP"){
		stop("The first parameter of umxPlotCP must be a CP model, you gave me a ", class(x))
	}
	format = match.arg(format)
	model = x # just to emphasise that x has to be a model 
	if(std){
		model = umx_standardize_CP(model)
	}
	# TODO Check I am handling nFac > 1 properly!!
	facCount = dim(model$top$a_cp$labels)[[1]]
	varCount = dim(model$top$as$values)[[1]]
	selDVs   = dimnames(model$MZ$data$observed)[[2]]
	selDVs   = selDVs[1:(varCount)]
	selDVs   = sub("(_T)?[0-9]$", "", selDVs) # trim "_Tn" from end

	parameterKeyList = omxGetParameters(model)
	out = "";
	latents = c();
	cSpecifics = c();
	for(thisParam in names(parameterKeyList) ) {
		# TODO: plot functions are in the process of being made more intelligent. see: umxPlotCPnew()
		# This version looks at labels. The new versions will loos directly at the relevant matrices
		# this breaks the dependency on label structure, allowing arbitrary and more flexible labelling
		# Top level a c e inputs to common factors
		if( grepl("^[ace]_cp_r[0-9]", thisParam)) { 
			# Match cp latents, e.g. thisParam = "c_cp_r1c3" (note, row = factor #)
			from    = sub("^([ace]_cp)_r([0-9])"  , '\\1\\2'   , thisParam, perl= TRUE); # "a_cp<r>"
			target  = sub("^([ace]_cp)_r([0-9]).*", 'common\\2', thisParam, perl= TRUE); # "common<r>"
			latents = append(latents, from)
		} else if (grepl("^cp_loadings_r[0-9]+", thisParam)) {
			# Match common loading string e.g. "cp_loadings_r1c1"
			from    = sub("^cp_loadings_r([0-9]+)c([0-9]+)", "common\\2", thisParam, perl= TRUE); # "common<c>"
			thisVar = as.numeric(sub('cp_loadings_r([0-9]+)c([0-9]+)', '\\1', thisParam, perl= TRUE)); # var[r]
			target  = selDVs[as.numeric(thisVar)]
			latents = append(latents,from)
		} else if (grepl("^[ace]s_r[0-9]", thisParam)) {
			# Match specifics, e.g. thisParam = "es_r10c10"
			grepStr = '([ace]s)_r([0-9]+)c([0-9]+)'
			from    = sub(grepStr, '\\1\\3', thisParam, perl= TRUE);
			targetindex = as.numeric(sub(grepStr, '\\2', thisParam, perl= TRUE));
			target  = selDVs[as.numeric(targetindex)]			
			latents = append(latents, from)
			cSpecifics = append(cSpecifics, from);
		} else if (grepl("^(exp)?[Mm]ean", thisParam)) { # means probably expMean_r1c1
			grepStr = '(^.*)_r([0-9]+)c([0-9]+)'
			from    = "one"
			targetindex = as.numeric(sub(grepStr, '\\3', thisParam, perl= TRUE))
			target  = selDVs[as.numeric(targetindex)]
		} else if (grepl("_dev[0-9]", thisParam)) { # is a threshold
			# Doesn't need plotting? # TODO umxPlotCP could tabulate thresholds?
			from = "do not plot"
		} else {
			message("While making the plot, I found a path labeled ", thisParam, "\nI don't know where that goes.\n",
			"If you are using umxModify to make newLabels, re-use one of the existing labels to help plot()")
		}
		if(from == "do not plot" || (from == "one" & !means) ){
			# either this is a threshold, or we're not adding means...
		} else {
			# Get parameter value and make the plot string
			# Convert address to [] address and look for a CI: not perfect, as CI might be label based?
			# If the model already has CIs stashed umx_stash_CIs() then pointless and harmful.
			# Also fails to understand not using _std?
			CIstr = umx_APA_model_CI(model, cellLabel = thisParam, prefix = "top.", suffix = "_std", SEstyle = SEstyle, digits = digits)
			if(is.na(CIstr)){
				val = umx_round(parameterKeyList[thisParam], digits)
			}else{
				val = CIstr
			}
			out = paste0(out, ";\n", from, " -> ", target, " [label=\"", val, "\"]")
		}
	}
	preOut = "# Latents\n"
	latents = unique(latents)
	for(var in latents) {
	   preOut = paste0(preOut, "\t", var, " [shape = circle];\n")
	}
	preOut = paste0(preOut, "\n# Manifests\n")
	for(n in c(1:varCount)) {
	   preOut = paste0(preOut, "\n\t", selDVs[n], " [shape = square];\n")
	}
	
	ranks = paste(cSpecifics, collapse = "; ");
	ranks = paste0("{rank=sink; ", ranks, "}");
	digraph = paste0("digraph G {\nsplines=\"FALSE\";\n", preOut, ranks, out, "\n}");
	if(format != "current"){
		umx_set_plot_format(format)
	} 
	xmu_dot_maker(model, file, digraph, strip_zero = strip_zero)
}

#' @export
plot.MxModelCP <- umxPlotCP

#' Draw a graphical figure for a Independent Pathway model
#'
#' Options include digits (rounding), showing means or not, standardization, and which output format is desired.
#'
#' @aliases plot.MxModelIP
#' @param x The \code{\link{umxIP}} model to plot
#' @param file The name of the dot file to write: NA = none; "name" = use the name of the model
#' @param digits How many decimals to include in path loadings (defaults to 2)
#' @param means Whether to show means paths (defaults to FALSE)
#' @param std whether to standardize the model (defaults to TRUE)
#' @param format = c("current", "graphviz", "DiagrammeR")
#' @param SEstyle report "b (se)" instead of b CI95[l,u] (default = FALSE)
#' @param strip_zero Whether to strip the leading "0" and decimal point from parameter estimates (default = TRUE)
#' @param ... Optional additional parameters
#' @return - optionally return the dot code
#' @export
#' @seealso - \code{\link{plot}()}, \code{\link{umxSummary}()} work for IP, CP, GxE, SAT, and ACE models.
#' @seealso - \code{\link{umxIP}}
#' @family Plotting functions
#' @references - \url{https://tbates.github.io}
#' @examples
#' \dontrun{
#' plot(model)
#' umxPlotIP(model, file = NA)
#' }
umxPlotIP  <- function(x = NA, file = "name", digits = 2, means = FALSE, std = TRUE, format = c("current", "graphviz", "DiagrammeR"), SEstyle = FALSE, strip_zero = TRUE, ...) {
	format = match.arg(format)
	if(!class(x) == "MxModelIP"){
		stop("The first parameter of umxPlotIP must be an IP model, you gave me a ", class(x))
	}
	
	model = x # to emphasise that x has to be an umxIP model
	if(std){
		model = umx_standardize_IP(model)
	}
	# TODO Check I am handling nFac > 1 properly!!
	varCount = dim(model$top$ai$values)[[1]]
	selDVs   = dimnames(model$MZ$data$observed)[[2]]
	selDVs   = selDVs[1:(varCount)]
	parameterKeyList = omxGetParameters(model, free = TRUE);
	out = "";
	cSpecifics = c();
	latents = c()
	for(thisParam in names(parameterKeyList) ) {
		if( grepl("^[ace]i_r[0-9]", thisParam)) {
			# top level a c e
			# "ai_r1c1" note: c1 = factor1, r1 = variable 1
			# devtools::document("~/bin/umx.twin"); devtools::install("~/bin/umx.twin");
			grepStr = '^([ace]i)_r([0-9]+)c([0-9]+)'
			from    = sub(grepStr, '\\1_\\3', thisParam, perl = TRUE);
			targetindex = as.numeric(sub(grepStr, '\\2', thisParam, perl=T));
			target  = selDVs[as.numeric(targetindex)]
			latents = append(latents,from);
		} else if (grepl("^[ace]s_r[0-9]", thisParam)) { # specific
			grepStr = '([ace]s)_r([0-9]+)c([0-9]+)'
			from    = sub(grepStr, '\\1\\3', thisParam, perl = T);
			targetindex = as.numeric(sub(grepStr, '\\2', thisParam, perl = T));
			target  = selDVs[as.numeric(targetindex)]
			cSpecifics = append(cSpecifics,from);
			latents = append(latents,from);
		} else if (grepl("^expMean", thisParam)) { # means probably expMean_r1c1
			grepStr = '(^.*)_r([0-9]+)c([0-9]+)'
			from    = "one";
			targetindex = as.numeric(sub(grepStr, '\\3', thisParam, perl=T));
			target  = selDVs[as.numeric(targetindex)];
		} else {
			message("While making the plot, I found a path labeled ", thisParam, "I don't know where that goes.\n",
			"If you are using umxModify to make newLabels, instead of making up a new label, use, say, the first label in update as the newLabel to help plot()")
		}

		if(!means & from == "one"){
			# not adding means...
		} else {
			CIstr = umx_APA_model_CI(model, cellLabel = thisParam, prefix = "top.", suffix = "_std", digits = digits, SEstyle = SEstyle, verbose = FALSE)
			if(is.na(CIstr)){
				val = round(parameterKeyList[thisParam], digits)
			}else{
				val = CIstr
			}
			out = paste0(out, ";\n", from, " -> ", target, " [label=\"", val, "\"]")
		}
		# devtools::document("~/bin/umx.twin"); devtools::install("~/bin/umx.twin");
	}

	preOut = "\t# Latents\n"
	latents = unique(latents)
	for(var in latents) {
	   preOut = paste0(preOut, "\t", var, " [shape = circle];\n")
	}
	preOut = paste0(preOut, "\n\t# Manifests\n")
	for(n in c(1:varCount)) {
	   preOut = paste0(preOut, "\n", selDVs[n], " [shape=square];\n")
	}

	ranks = paste(cSpecifics, collapse = "; ");
	ranks = paste0("{rank=sink; ", ranks, "}");
	digraph = paste0("digraph G {\nsplines=\"FALSE\";\n", preOut, ranks, out, "\n}");
	if(format != "current"){
		umx_set_plot_format(format)
	}
	xmu_dot_maker(model, file, digraph, strip_zero = strip_zero)
}

#' @export
plot.MxModelIP <- umxPlotIP

#' Report modifications which would improve fit.
#'
#' This function uses the mechanical modification-indices approach to detect single paths which, if added
#' or dropped, would improve fit.
#' 
#' Notes:
#' 1. Runs much faster with full = FALSE (but this does not allow the model to re-fit around the newly-
#' freed parameter).
#' 2. Compared to mxMI, this function returns top changes, and also suppresses the run message.
#' 3. Finally, of course: see the requirements for (legitimate) post-hoc modeling in \code{\link{mxMI}}
#' You are almost certainly doing better science when testing competing models rather than modifying a model to fit.
#' @param model An \code{\link{mxModel}} for which to report modification indices
#' @param matrices which matrices to test. The default (NA) will test A & S for RAM models
#' @param full Change in fit allowing all parameters to move. If FALSE only the parameter under test can move.
#' @param numInd How many modifications to report. Use -1 for all. Default (NA) will report all over 6.63 (p = .01)
#' @param typeToShow Whether to shown additions or deletions (default = "both")
#' @param decreasing How to sort (default = TRUE, decreasing)
#' @seealso - \code{\link{mxMI}}
#' @family Modify or Compare Models
#' @references - \url{https://www.github.com/tbates/umx}
#' @export
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)[1:3]
#' df = mxData(cov(demoOneFactor[,manifests]), type = "cov", numObs = 500)
#' m1 <- umxRAM("One Factor", data = df,
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' umxMI(m1, full=FALSE)
umxMI <- function(model = NA, matrices = NA, full = TRUE, numInd = NA, typeToShow = "both", decreasing = TRUE) {
	if(typeToShow != "both"){
		message("Only showing both add and remove is supported so far")
	}
	if(is.na(matrices)){
		if(umx_is_RAM(model)){
			matrices = c("A", "S")
		}else{
			message("You need to tell me which matrices to test (this is not a RAM model, so I don't know.)")
		}
	}
	suppressMessages({MI = mxMI(model = model, matrices = matrices, full = full)})
	if(full){
		MIlist = MI$MI.Full
	} else {
		MIlist = MI$MI
	}
	if(is.na(numInd)){
		thresh = qchisq(p = (1 - 0.01), df = 1) # 6.63
		# check how many
		nSig = length(MIlist[MIlist > thresh])
		if(nSig < 1){
			# nothing significant, display top 3 or so
			mostPossible = length(MIlist)
			numInd = min(3, mostPossible)
			suggestions = sort(MIlist, decreasing = decreasing)[1:numInd]
		} else {
			suggestions = sort(MIlist[MIlist > thresh], decreasing = decreasing)
		}		
	} else {
		suggestions = sort(MIlist, decreasing = decreasing)[1:numInd]
	}
	print(suggestions)
	invisible(MI)
}

# ======================
# = Path tracing rules =
# ======================
#' umxUnexplainedCausalNexus
#'
#' umxUnexplainedCausalNexus report the effect of a change (delta) in a variable (from) on an output (to)
#'
#' @param from A variable in the model for which you want to compute the effect of a change.
#' @param delta A the amount to simulate changing \sQuote{from} by. 
#' @param to The dependent variable that you want to watch changing.
#' @param model The model containing variables from and to.
#' @seealso - \code{\link{mxCheckIdentification}}, \code{\link{mxCompare}}
#' @family Modify or Compare Models
#' @references - https://www.github.com/tbates/umx/
#' @export
#' @examples
#' \dontrun{
#' umxUnexplainedCausalNexus(from="yrsEd", delta = .5, to = "income35", model)
#' }
umxUnexplainedCausalNexus <- function(from, delta, to, model= NULL) {
	umx_check_model(model, type = "RAM")
	
	manifests = model@manifestVars
	partialDataRow <- matrix(0, 1, length(manifests))  # add dimnames to allow access by name
	dimnames(partialDataRow) = list("val", manifests)
	partialDataRow[1, from] <- delta # delta is in raw "from" units
	partialDataRow[1, to]   <- NA
	completedRow <- umxConditionalsFromModel(model, partialDataRow, meanOffsets = TRUE)
	# by default, meanOffsets = FALSE, and the results take expected means into account
	return(completedRow[1, to])
}

umxConditionalsFromModel <- function(model, newData = NULL, returnCovs = FALSE, meanOffsets = FALSE) {
	# original author: [Timothy Brick](https://www.github.com/tbates/umx/users/tbrick)
	# [history](https://www.github.com/tbates/umx/thread/2076)
	# Called by: umxUnexplainedCausalNexus
	# TODO:  Special case for latent variables
	expectation <- model$objective
	A <- NULL
	S <- NULL
	M <- NULL
	
	# Handle missing data
	if(is.null(newData)) {
		data <- model$data
		if(data$type != "raw") {
			stop("Conditionals requires either new data or a model with raw data.")
		}
		newData <- data$observed
	}
	
	# New fit-function style
	eCov  <- model$fitfunction$info$expCov
	eMean <- model$fitfunction$info$expMean
	expectation <- model$expectation
	if(!length(setdiff(c("A", "S", "F"), names(getSlots(class(expectation)))))) {
		A <- eval(substitute(model$X$values, list(X=expectation$A)))
		S <- eval(substitute(model$X$values, list(X=expectation$S)))
		if("M" %in% names(getSlots(class(expectation))) && !is.na(expectation$M)) {
			M <- eval(substitute(model$X$values, list(X=expectation$M)))
		}
	}

	if(!is.null(A)) {
		# RAM model: calculate total expectation
		I <- diag(nrow(A))
		Z <- solve(I-A)
		eCov <- Z %*% S %*% t(Z)
		if(!is.null(M)) {
			eMean <- Z %*% t(M)
		}
		latents <- model@latentVars
		newData <- data.frame(newData, matrix(NA, ncol=length(latents), dimnames=list(NULL, latents)))
	}
	
	# No means
	if(meanOffsets || !dim(eMean)[1]) {
		eMean <- matrix(0.0, 1, ncol(eCov), dimnames=list(NULL, colnames(eCov)))
	}
	
	# TODO: Sort by pattern of missingness, lapply over patterns
	nRows = nrow(newData)
	outs <- omxApply(newData, 1, umxComputeConditionals, sigma=eCov, mu=eMean, onlyMean=!returnCovs)
	if(returnCovs) {
		means <- matrix(NA, nrow(newData), ncol(eCov))
		covs <- rep(list(matrix(NA, nrow(eCov), ncol(eCov))), nRows)
		for(i in 1:nRows) {
			means[i,] <- outs[[i]]$mu
			covs[[i]] <- outs[[i]]$sigma
		}
		return(list(mean = means, cov = covs))
	}
	return(t(outs))
}

umxComputeConditionals <- function(sigma, mu, current, onlyMean = FALSE) {
	# Usage: umxComputeConditionals(model, newData)
	# Result is a replica of the newData data frame with missing values and (if a RAM model) latent variables populated.
	# original author: [Timothy Brick](https://www.github.com/tbates/umx/users/tbrick)
	# [history](https://www.github.com/tbates/umx/thread/2076)
	# called by umxConditionalsFromModel()
	if(dim(mu)[1] > dim(mu)[2] ) {
		mu <- t(mu)
	}

	nVar <- length(mu)
	vars <- colnames(sigma)

	if(!is.matrix(current)) {
		current <- matrix(current, 1, length(current), dimnames=list(NULL, names(current)))
	}
	
	# Check inputs
	if(dim(sigma)[1] != nVar || dim(sigma)[2] != nVar) {
		stop("Non-conformable sigma and mu matrices in conditional computation.")
	}
	
	if(is.null(vars)) {
		vars <- rownames(sigma)
		if(is.null(vars)) {
			vars <- colnames(mu)
			if(is.null(vars)) {
				vars <- names(current)
				if(is.null(vars)) {
					vars <- paste("X", 1:dim(sigma)[1], sep = "")
					names(current) <- vars
				}
				names(mu) <- vars
			}
			dimnames(sigma) <- list(vars, vars)
		}
		rownames(sigma) <- vars
	}
	
	if(is.null(colnames(sigma))) {
		colnames(sigma) <- vars
	}
	
	if(is.null(rownames(sigma))) {
		rownames(sigma) <- colnames(sigma)
	}

	if(!setequal(rownames(sigma), colnames(sigma))) {
		stop("Rows and columns of sigma do not match in conditional computation.")
	}
	
	if(!setequal(rownames(sigma), vars) || !setequal(colnames(sigma), vars)) {
		stop("Names of covariance and means in conditional computation fails.")
	}
	
	if(length(current) == 0) {
		if(onlyMean) {
			return(mu)
		}
		return(list(sigma=covMat, mu=current))
	}
	
	if(is.null(names(current))) {
		if(length(vars) == 0 || ncol(current) != length(vars)) {
			print(paste("Got data vector of length ", ncol(current), " and names of length ", length(vars)))
			stop("Length and names of current values mismatched in conditional computation.")
		}
		names(current) <- vars[1:ncol(current)]
	}
	
	if(is.null(names(current))) {
		if(length(vars) == 0 || ncol(current) != length(vars)) {
			if(length(vars) == 0 || ncol(current) != length(vars)) {
				print(paste("Got mean vector of length ", ncol(current), " and names of length ", length(vars)))
				stop("Length and names of mean values mismatched in conditional computation.")
			}
		}
		names(mu) <- vars
	}
	
	# Get Missing and Non-missing sets
	if(!setequal(names(current), vars)) {
		newSet <- setdiff(vars, names(current))
		current[newSet] <- NA
		current <- current[vars]
	}
	
	# Compute Schur Complement
	# Calculate parts:
	missing <- names(current[is.na(current)])
	nonmissing <- setdiff(vars, missing)
	ordering <- c(missing, nonmissing)
	
	totalCondCov <- NULL

	# Handle all-missing and none-missing cases
	if(length(missing) == 0) {
		totalMean = current
		names(totalMean) <- names(current)
		totalCondCov = sigma
	} 

	if(length(nonmissing) == 0) {
		totalMean = mu
		names(totalMean) <- names(mu)
		totalCondCov = sigma
	}

	# Compute Conditional expectations
	if(is.null(totalCondCov)) {
		
		covMat <- sigma[ordering, ordering]
		missMean <- mu[, missing]
		haveMean <- mu[, nonmissing]

		haves <- current[nonmissing]
		haveNots <- current[missing]

		missCov <- sigma[missing, missing]
		haveCov <- sigma[nonmissing, nonmissing]
		relCov <- sigma[missing, nonmissing]
		relCov <- matrix(relCov, length(missing), length(nonmissing))

		invHaveCov <- solve(haveCov)
		condMean <- missMean + relCov %*% invHaveCov %*% (haves - haveMean)

		totalMean <- current * 0.0
		names(totalMean) <- vars
		totalMean[missing] <- condMean
		totalMean[nonmissing] <- current[nonmissing]
	}

	if(onlyMean) {
		return(totalMean)
	}
	
	if(is.null(totalCondCov)) {
		condCov <- missCov - relCov %*% invHaveCov %*% t(relCov)
	
		totalCondCov <- sigma * 0.0
		totalCondCov[nonmissing, nonmissing] <- haveCov
		totalCondCov[missing, missing] <- condCov
	}	
	return(list(sigma=totalCondCov, mu=totalMean))
	
}

# =========================
# = Pull model components =
# =========================

#' Display path estimates from a model, filtering by name and value.
#'
#' @description
#' Often you want to see the estimates from a model, and often you don't want all of them.
#' \code{\link{umx_parameters}} helps in this case, allowing you to select parameters matching a name filter,
#' and also to only show parameters above or below a certain value.
#' 
#' If pattern is a vector, each regular expression is matched, and all unique matches to the whole vector are returned.
#'
#' @details
#' It is on my TODO list to implement filtering by significance, and to add standardizing.
#'
#' @param x an \code{\link{mxModel}} or model summary from which to report parameter estimates.
#' @param thresh optional: Filter out estimates 'below' or 'above' a certain value (default = "all").
#' @param b Combine with thresh to set a minimum or maximum for which estimates to show.
#' @param pattern Optional string to match in the parameter names. Default '.*' matches all. \code{\link{regex}} allowed!
#' @param std Standardize output: NOT IMPLEMENTED YET
#' @param digits Round to how many digits (2 = default).
#' @return - list of matching parameters, filtered by name and value
#' @export
#' @family Reporting Functions
#' @seealso - \code{\link{parameters}}, \code{\link{umxSummary}}, \code{\link{umx_names}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(demoOneFactor, type = "raw"),
#' 	umxPath(from = "G", to = manifests),
#' 	umxPath(v.m. = manifests),
#' 	umxPath(v1m0 = "G")
#' )
#' # Parameters with values below .1
#' umx_parameters(m1, "below", .1)
#' # Parameters with values above .5
#' umx_parameters(m1, "above", .5)
#' # Parameters with values below .1 and containing "_to_" in their label
#' umx_parameters(m1, "below", .1, "_to_")
umx_parameters <- function(x, thresh = c("all", "above", "below", "NS", "sig"), b = NULL, pattern = ".*", std = FALSE, digits = 2) {
	# TODO rationalize (deprecate?) umx_parameters and umxGetParameters -> just parameters()
	# TODO Add filtering by significance (based on SEs)
	# TODO Offer a method to handle sub-models
	# 	model$aSubmodel$matrices$aMatrix$labels
	# 	model$MZ$matrices
	
	if(std){
		stop("Sorry, std not implemented yet: Standardize the model and provide this or the summary as input.")
	}
	# x = cp4
	if(class(thresh) == "numeric"){
		stop("You might not have specified the parameter value (b) by name. e.g.:\n
	parameters(cp4, pattern = '_cp_', thresh = 'below', b = .1)\n
or specify all arguments:\n
	parameters(cp4, 'below', .1, '_cp_')
		")
	}
	thresh <- match.arg(thresh)

	if(!is.null(b) && (thresh == "all")){
		message("Ignoring b (cutoff) and thresh = all. Set above or below to pick a beta to cut on.")
	}
	if(class(x) != "summary.mxmodel"){
		if(umx_has_been_run(x)){
			x = summary(x)
		} else {
			# message("Just a note: Model has not been run. That might not matter for you")
		}
	}
	if(class(x) != "summary.mxmodel"){
		# must be a model that hasn't been run, make up a similar dataframe
		x = omxGetParameters(x)
		x = data.frame(name = names(x), Estimate = as.numeric(x), stringsAsFactors = FALSE)
	} else {
		x = x$parameters
	}

	# Handle 1 or more regular expressions.
	parList = c()
	for (i in 1:length(pattern)) {
		parList = c(parList, umx_names(x$name, pattern = pattern[i]))
	}
	parList = unique(parList)
	
	if(thresh == "above"){
		filter = x$name %in% parList & abs(x$Estimate) > b
	} else if(thresh == "below"){
		filter = x$name %in% parList & abs(x$Estimate) < b
	} else if(thresh == "all"){
		filter = x$name %in% parList
	} else if(thresh == "NS"){
		stop("NS and Sig not implemented yet: email tim to get this done.")
	} else if(thresh == "sig"){
		stop("NS and Sig not implemented yet: email tim to get this done.")
	}

	if(sum(filter) == 0){
		message(paste0("Nothing found matching pattern ", omxQuotes(pattern), " and minimum absolute value ", thresh, " ", b, "."))
		
		paste0("Might try flipping the from and to elements of the name, or look in these closest matches for what you intended: ",
			omxQuotes(agrep(pattern = pattern, x = x$name, max.distance = 4, value = TRUE))
		)
	} else {
		umx_round(x[filter, c("name", "Estimate")], digits = digits)
	}
}

#' @rdname umx_parameters
#' @export
umxParameters <- umx_parameters

#' @rdname umx_parameters
#' @export
parameters <- umx_parameters

#' Get parameters from a model, with support for pattern matching!
#'
#' umxGetParameters retrieves parameter labels from a model, like \code{\link{omxGetParameters}}.
#' However, it is supercharged with regular expressions, so you can get labels that match a pattern.
#' 
#' In addition, if regex contains a vector, this is treated as a list of raw labels to search for, 
#' and return if all are found.
#' \emph{note}: To return all labels, just leave regex as is.
#'
#' @param inputTarget An object to get parameters from: could be a RAM \code{\link{mxModel}}
#' @param regex A regular expression to filter the labels. Default (NA) returns all labels. Vector treated as raw labels to find.
#' @param free  A Boolean determining whether to return only free parameters.
#' @param fetch What to return: "values" (default) or "free", "lbound", "ubound", or "all"
#' @param verbose How much feedback to give
#' @export
#' @seealso \code{\link{omxGetParameters}}, \code{\link{umx_parameters}}
#' @family Reporting Functions
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' 
#' # Show all parameters
#' umxGetParameters(m1)
#' umxGetParameters(m1, free = TRUE) # only parameters which are free 
#' umxGetParameters(m1, free = FALSE) # only parameters which are fixed
#' # Complex regex patterns
#' umxGetParameters(m1, regex = "x[1-3]_with_x[2-5]", free = TRUE)
#' 
umxGetParameters <- function(inputTarget, regex = NA, free = NA, fetch = c("values", "free", "lbound", "ubound", "all"), verbose = FALSE) {
	# TODO
	# 1. Be nice to offer a method to handle sub-models
	# 	model$aSubmodel$matrices$aMatrix$labels
	# 	model$MZ$matrices
	# 2. Simplify handling
		# allow umxGetParameters to function like omxGetParameters()[name filter]
	# 3. Allow user to request values, free, etc. (already done with umx_parameters)
	fetch = match.arg(fetch)
	if(umx_is_MxModel(inputTarget)) {
		topLabels = names(omxGetParameters(inputTarget, indep = FALSE, free = free))
	} else if(methods::is(inputTarget, "MxMatrix")) {
		if(is.na(free)) {
			topLabels = inputTarget$labels
		} else {
			topLabels = inputTarget$labels[inputTarget$free==free]
		}
	}else{
		stop("I am sorry Dave, umxGetParameters needs either a model or an mxMatrix: you offered a ", class(inputTarget)[1])
	}
	theLabels = topLabels[which(!is.na(topLabels))] # exclude NAs
	if( length(regex) > 1 || !is.na(regex) ) {
		if(length(regex) > 1){
			# assume regex is a list of labels
			theLabels = theLabels[theLabels %in% regex]
			if(length(regex) != length(theLabels)){
				msg = "Not all labels found! Missing were:\n"
				stop(msg, regex[!(regex %in% theLabels)]);
			}
		} else {
			# it's a grep string
			if(length(grep("[\\.\\*\\[\\(\\+\\|^]+", regex) ) < 1){ # no grep found: add some anchors for safety
				regex = paste0("^", regex, "[0-9]*$"); # anchor to the start of the string
				anchored = TRUE
				if(verbose == TRUE) {
					message("note: anchored regex to beginning of string and allowed only numeric follow\n");
				}
			}else{
				anchored = FALSE
			}
			theLabels = grep(regex, theLabels, perl = FALSE, value = TRUE) # return more detail
		}
		if(length(theLabels) == 0){
			msg = paste0("Found no labels matching", omxQuotes(regex), "!\n")
			if(anchored == TRUE){
				msg = paste0(msg, "note: anchored regex to beginning of string and allowed only numeric follow:\"", regex, "\"")
			}
			if(umx_is_MxModel(inputTarget)){
				msg = paste0(msg, "\nUse umxGetParameters(", deparse(substitute(inputTarget)), ") to see all parameters in the model")
			}else{
				msg = paste0(msg, "\nUse umxGetParameters() without a pattern to see all parameters in the model")
			}
			stop(msg);
		}
	}
	return(theLabels)
}


#' Extract AIC from MxModel
#'
#' Returns the AIC for an OpenMx model.
#' Original Author: Brandmaier
#'
#' @method extractAIC MxModel
#' @rdname extractAIC.MxModel
#' @export
#' @param fit an fitted \code{\link{mxModel}} from which to get the AIC
#' @param scale not used
#' @param k not used
#' @param ... any other parameters (not used)
#' @return - AIC value
#' @seealso - \code{\link{AIC}}, \code{\link{umxCompare}}, \code{\link{logLik}}
#' @family Reporting functions
#' @references - \url{https://openmx.ssri.psu.edu/thread/931#comment-4858}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' extractAIC(m1)
#' # -2.615998
#' AIC(m1)
extractAIC.MxModel <- function(fit, scale, k, ...) {
	a = mxCompare(fit)
	return(a[1, "AIC"])
}

#' Get the expected vcov matrix
#'
#' Extract the expected covariance matrix from an \code{\link{mxModel}}
#'
#' @aliases vcov.MxModel
#' @param object an \code{\link{mxModel}} to get the covariance matrix from
#' @param latents Whether to select the latent variables (defaults to TRUE)
#' @param manifests Whether to select the manifest variables (defaults to TRUE)
#' @param digits precision of reporting. NULL (Default) = no rounding.
#' @param ... extra parameters (to match \code{\link{vcov}})
#' @return - expected covariance matrix
#' @export
#' @family Reporting functions
#' @references - \url{https://openmx.ssri.psu.edu/thread/2598}
#' Original written by \url{https://openmx.ssri.psu.edu/users/bwiernik}
#' @seealso - \code{\link{umxRun}}, \code{\link{umxCI_boot}}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- mxModel("One Factor", type = "RAM", 
#' 	manifestVars = manifests, latentVars = latents, 
#' 	mxPath(from = latents, to = manifests),
#' 	mxPath(from = manifests, arrows = 2),
#' 	mxPath(from = latents, arrows = 2, free = FALSE, values = 1.0),
#' 	mxData(cov(demoOneFactor), type = "cov", numObs = 500)
#' )
#' m1 = umxRun(m1, setLabels = TRUE, setValues = TRUE)
#' vcov(m1)
#' umxExpCov(m1, digits = 3)
umxExpCov <- function(object, latents = FALSE, manifests = TRUE, digits = NULL, ...){
	# umx_has_been_run(m1)
	# TODO integrate with mxGetExpected(model, "covariance")
	# mxGetExpected(m1, component= c("means", "covariance", "standVector") )
	if(object$data$type == "raw"){
		manifestNames = names(object$data$observed)
	} else {
		manifestNames = dimnames(object$data$observed)[[1]]
	}
	if(umx_is_RAM(object)){
		if(manifests & !latents){
			# expCov = attr(object$objective[[2]]$result, "expCov")
			thisFit = paste0(object$name, ".fitfunction")
			expCov <- attr(object$output$algebras[[thisFit]], "expCov")
			dimnames(expCov) = list(manifestNames, manifestNames)
		} else {
			A <- mxEval(A, object)
			S <- mxEval(S, object)
			I <- diag(1, nrow(A))
			E <- solve(I - A)
			expCov <- E %&% S # The model-implied covariance matrix
			mV <- NULL
			if(latents) {
				mV <- object@latentVars 
			}
			if(manifests) {
				mV <- c(mV, object@manifestVars)
			}
			expCov = expCov[mV, mV]
		}
	} else {
		if(latents){
			stop("I don't know how to reliably get the latents for non-RAM objects... Sorry :-(")
		} else {
			expCov <- attr(object$output$algebras[[paste0(object$name, ".fitfunction")]], "expCov")
			dimnames(expCov) = list(manifestNames, manifestNames)
		}
	}
	if(!is.null(digits)){
		expCov = round(expCov, digits)
	}
	return(expCov) 
}

#' @export
vcov.MxModel <- umxExpCov


#' Extract the expected means matrix from an \code{\link{mxModel}}
#'
#' Extract the expected means matrix from an \code{\link{mxModel}}
#'
#' @param model an \code{\link{mxModel}} to get the means from
#' @param latents Whether to select the latent variables (defaults to TRUE)
#' @param manifests Whether to select the manifest variables (defaults to TRUE)
#' @param digits precision of reporting. Default (NULL) will not round at all.
#' @return - expected means
#' @export
#' @family Reporting functions
#' @references - \url{https://openmx.ssri.psu.edu/thread/2598}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- mxModel("One Factor", type = "RAM", 
#' 	manifestVars = manifests, latentVars = latents, 
#' 	mxPath(from = latents, to = manifests),
#' 	mxPath(from = manifests, arrows = 2),
#' 	mxPath(from = "one", to = manifests),
#' 	mxPath(from = latents, arrows = 2, free = FALSE, values = 1.0),
#' 	mxData(demoOneFactor[1:100,], type = "raw")
#' )
#' m1 = umxRun(m1, setLabels = TRUE, setValues = TRUE)
#' umxExpMeans(model = m1)
#' umxExpMeans(m1, digits = 3)
umxExpMeans <- function(model, manifests = TRUE, latents = NULL, digits = NULL){
	# TODO # what does umxExpMeans do under 1.4?
	umx_check_model(model, beenRun = TRUE)
	if(!umx_has_means(model)){
		stop("Model has no means expectation to get: Are there any means in the data? (type='raw', or type = 'cov' with means?)")
	}
	
	if(umx_is_RAM(model)){
		# TODO something nice to do here?
	}
	if(!is.null(latents)){
		# TODO should a function called expMeans get expected means for latents... why not.
		stop("Haven't thought about getting means for latents yet... Bug me about it :-)")
	}
	expMean <- attr(model$output$algebras[[paste0(model$name, ".fitfunction")]], "expMean")
	
	if(model$data$type == "raw"){
		manifestNames = names(model$data$observed)
	} else {
		manifestNames = dimnames(model$data$observed)[[1]]
	}
	dimnames(expMean) = list("mean", manifestNames)
	if(!is.null(digits)){
		expMean = round(expMean, digits)
	}
	return(expMean)
}


# define generic RMSEA...
#' Generic RMSEA function
#'
#' See \code{\link[umx]{RMSEA.MxModel}} to access the RMSEA of MxModels
#'
#' @param x an object from which to get the RMSEA 
#' @param ci.lower the lower CI to compute
#' @param ci.upper the upper CI to compute
#' @param digits digits to show
#' @return - RMSEA object containing value (and perhaps a CI)
#' @export
#' @family Reporting functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}, \url{https://openmx.ssri.psu.edu}
RMSEA <- function(x, ci.lower, ci.upper, digits) UseMethod("RMSEA", x)

#' RMSEA function for MxModels
#'
#' Compute the confidence interval on RMSEA
#'
#' @param x an \code{\link{mxModel}} from which to get RMSEA
#' @param ci.lower the lower CI to compute
#' @param ci.upper the upper CI to compute
#' @param digits digits to show (defaults to 3)
#' @return - object containing the RMSEA and lower and upper bounds
#' @rdname RMSEA.MxModel
#' @export
#' @family Reporting functions
#' @references - \url{https://github.com/simsem/semTools/wiki/Functions}, \url{https://github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1.0)
#' )
#' RMSEA(m1)
RMSEA.MxModel <- function(x, ci.lower = .05, ci.upper = .95, digits = 3) { 
	sm <- summary(x)
	RMSEA.summary.mxmodel(x= sm, ci.lower = ci.lower, ci.upper = ci.upper, digits = digits)
}

#' RMSEA function for MxModels
#'
#' Compute the confidence interval on RMSEA
#'
#' @param x an \code{\link{mxModel}} summary from which to get RMSEA
#' @param ci.lower the lower CI to compute
#' @param ci.upper the upper CI to compute
#' @param digits digits to show (defaults to 3)
#' @return - object containing the RMSEA and lower and upper bounds
#' @rdname RMSEA.summary.mxmodel
#' @export
#' @family Reporting functions
#' @references - \url{https://github.com/simsem/semTools/wiki/Functions}, \url{https://github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1.0)
#' )
#' RMSEA(m1)
RMSEA.summary.mxmodel <- function(x, ci.lower = .05, ci.upper = .95, digits = 3){
	if(ci.lower != .05 | ci.upper != .95){
		stop("only 95% CI on RMSEA supported as yet...")
	}
	txt = paste0("RMSEA = ", round(x$RMSEA, digits))
	txt = paste0(txt, " CI", sub("^0?\\.", replacement = "", ci.upper))
	txt = paste0(txt, "[", round(x$RMSEACI["lower"], digits), ", ")
	txt = paste0(txt, round(x$RMSEACI["upper"], digits), "], ")
	txt = paste0(txt, "Prob(RMSEA <= 0.05) = ", umx_APA_pval(x$RMSEAClose))
	print(txt)
	invisible(list(RMSEA = x$RMSEA, CI.lower = x$RMSEACI["lower"], 
		CI.upper = x$RMSEACI["upper"], RMSEA.pvalue = x$RMSEAClose, txt = txt)
	)
}

# ===================================
# = summary Stats and table helpers =
# ===================================

#' umx_fun
#'
#' Miscellaneous functions that are handy in summary and other tasks where you might otherwise have
#' to craft a custom nameless functions. e.g.
#' 
#' \itemize{
#'   \item \code{\link{umx_fun_mean_sd}}: returns "mean (SD)" of x.
#'   \item Second item
#' }
#' note: if a factor is given, then the mode is returned instead of the mean and SD.
#' @param x input
#' @param na.rm How to handle missing (default = TRUE = remove)
#' @param digits Rounding (default = 2)
#' @return - function result
#' @export
#' @family Miscellaneous Stats Helpers
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' umxAPA(mtcars[,1:3]) # uses umx_fun_mean_sd
umx_fun_mean_sd = function(x, na.rm = TRUE, digits = 2){
	if(!is.numeric(x)){
		paste0("mode = ", names(which.max(table(x))))
	} else {
		paste0(
			round(mean(x, na.rm = na.rm), digits), " ",
			"(", round(sd(x, na.rm = na.rm),digits = digits), ")"
	)
	}
}

#' Convenient formula-based cross-tabs & built-in summary functions
#'
#' @description
#' A common task is preparing summary tables, aggregating over some grouping factor.
#' Like mean and sd of age, by sex. R's \code{\link{aggregate}} function is useful and powerful, allowing
#' xtabs based on a formula.
#' 
#' umx_aggregate makes using it a bit easier. In particular, it has some common functions 
#' for summarizing data built-in, like "mean (sd)" (the default).
#' 
#' \code{umx_aggregate(mpg ~ cyl, data = mtcars, what = "mean_sd")}
#' 
#' \tabular{ll}{
#' cyl        \tab mpg\cr
#' 4 (n = 11) \tab 26.66 (4.51)\cr
#' 6 (n = 7)  \tab 19.74 (1.45)\cr
#' 8 (n = 14) \tab 15.1 (2.56)\cr
#' }
#'
#' @param formula The aggregation formula. e.g., DV ~ condition.
#' @param data frame to aggregate.
#' @param what function to use. Default reports "mean (sd)".
#' @param digits to round results to.
#' @param report Format for the table: Default is markdown.
#' @return - table
#' @export
#' @family Reporting Functions
#' @seealso - \code{\link{umx_apply}}, \code{\link{aggregate}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' # =====================================
#' # = Basic use, compare with aggregate =
#' # =====================================
#' aggregate(mpg ~ cyl, FUN = mean, na.rm = TRUE, data = mtcars)
#' umx_aggregate(mpg ~ cyl, data = mtcars)
#' 
#' # =============================================
#' # = Use different (or user-defined) functions =
#' # =============================================
#' umx_aggregate(mpg ~ cyl, data = mtcars, what = "n")
#' umx_aggregate(mpg ~ cyl, data = mtcars, what = function(x){sum(!is.na(x))})
#' 
#' # turn off markdown
#' umx_aggregate(mpg ~ cyl, data = mtcars, report = "txt")
#' 
#' # ============================================
#' # = More than one item on the left hand side =
#' # ============================================
#' umx_aggregate(cbind(mpg, qsec) ~ cyl, data = mtcars, digits = 3)
#' # Transpose table
#' t(umx_aggregate(cbind(mpg, qsec) ~ cyl, data = mtcars))
#' 
#' \dontrun{
#' umx_aggregate(cbind(moodAvg, mood) ~ condition, data = study1)
#' }
umx_aggregate <- function(formula = DV ~ condition, data = NA, what = c("mean_sd", "n"), digits = 2, report = c("markdown", "html", "txt")) {
	report = match.arg(report)
	what = umx_match.arg(what, c("mean_sd", "n"), check = FALSE)
	# TODO Add more aggregating functions?
	# 	output odds or odds ratios for binary?
	# TODO: add summaryBy ability to handle more than var on the left hand side
	# doBy::summaryBy(Sex_T1 + Sex_T2 ~ zyg, data = twinData, FUN = function(x) { round(c(
	# 	n    = length(x),
	# 	mean = mean(x, na.rm = T),
	# 	sd   = sd(x, na.rm = T)), 2)
	# })
	# TODO: add "sep" to umx_aggregate to make wide data long for summary as in genEpi_TwinDescriptives
	# genEpi_TwinDescriptives(mzData = twinData, dzData = NULL, selDVs = selDVs, groupBy = c("Sex_T1", "Sex_T2"), graph = F)
	# genEpi_twinDescribe(twinData, varsToSummarize="Age", groupBy="Sex", suffix="_T")

	mean_sd = function(x){
		if(is.numeric(x)){
			paste0(round(mean(x, na.rm = TRUE), digits = digits), " (",
				   round(sd(x, na.rm = TRUE), digits = digits), ")"
			)
		} else {
			paste0(names(table(x))," ", table(x), collapse = "; ")
		}
	}
	x_n = function(x){sum(!is.na(x))}

	if(class(what)=="function"){
		FUN = what
	} else if(class(what) != "character"){
		stop("umx_aggregate what should be a built-in name like 'mean_sd', or a function, you gave me a", class(what))
	} else if(what == "mean_sd"){
		FUN = mean_sd
	} else if(what == "n"){
		FUN = x_n
	}
	tmp = aggregate(formula, FUN = FUN, data = data)
	n_s = aggregate(formula, FUN = x_n, data = data)
	tmp = data.frame(tmp)
	tmp[, 1] = paste0(as.character(tmp[, 1]), " (n = ", n_s[, 2], ")")
	if(report == "html"){
		umx_print(tmp, digits = digits, file = "tmp.html")
	} else if(report == "markdown"){
		return(knitr::kable(tmp))
	}else{
		# umx_print(tmp, digits = digits)
		return(tmp)
	}
}

#' Round p-values according to APA guidelines
#'
#' @description
#' umx_APA_pval formats p-values, rounded correctly. So you get '< .001' instead of .000000002 or 1.00E-09.
#' 
#' You set the precision with digits. Optionally, you can add '=' '<' etc. The default for addComparison (NA) adds these when needed.
#'
#' @param p The p-value to round
#' @param min Values below min will be reported as "< min"
#' @param digits Number of decimals to which to round (default = 3)
#' @param addComparison Whether to add '=' '<' etc. (NA adds when needed)
#' @family Reporting Functions
#' @return - p-value formatted in APA style
#' @export
#' @seealso - \code{\link{umxAPA}}, \code{\link{round}}
#' @examples
#' umx_APA_pval(.052347)
#' umx_APA_pval(1.23E-3)
#' umx_APA_pval(1.23E-4)
#' umx_APA_pval(c(1.23E-3, .5))
#' umx_APA_pval(c(1.23E-3, .5), addComparison = TRUE)
umx_APA_pval <- function(p, min = .001, digits = 3, addComparison = NA) {
	# FIXME delete in favor of umxAPA?
	if(length(p) > 1){
		o = rep(NA, length(p))
		for(i in seq_along(p)) {
		   o[i] = umx_APA_pval(p[i], min = min, digits = digits, addComparison = addComparison)
		}
		return(o)
	} else {
		if(is.nan(p) | is.na(p)){
			if(is.na(addComparison)){
				return(p)
			}else if(addComparison){
				return(paste0("= ", p))
			} else {
				return(p)
			}
		}
		if(p < min){
			if(is.na(addComparison)){
				return(paste0("< ", min))
			}else if(addComparison){
				return(paste0("< ", min))
			} else {
				return(min)
			}
		} else {
			if(is.na(addComparison)){
				return(format(round(p, digits), scientific = FALSE, nsmall = digits))
			}else if(addComparison){				
				return(paste0("= ", format(round(p, digits), scientific = FALSE, nsmall = digits)))
			} else {
				return(round(p, digits))
			}
		}	
	}
}

#' Creates nicely formatted journal style summaries of lm models, p-values, data-frames etc.
#'
#' @description
#' umxAPA creates summaries from a range of inputs. Use it for reporting lm models, effects, and summarizing data.
#' 
#' 1. Given an lm, will return a formatted effect, including 95\% CI 
#' in square brackets, for one of the effects (specified by name in se). e.g.:
#' \code{\link{umxAPA}}(m1, "wt") yields:
#' 
#' \eqn{\beta} = -5.344 [-6.486, -4.203], p< 0.001
#' 
#' 2. Given a dataframe, summaryAPA will return a table of correlations, with
#' the mean and SD of each variable as the last row. So, 
#' \code{umxAPA(mtcars[,c("cyl", "wt", "mpg", )])} yields a table of 
#' correlations, means and SDs thus:
#' 
#'\tabular{lccc}{
#'         \tab cyl         \tab  wt          \tab mpg          \cr
#' cyl     \tab 1           \tab  0.78        \tab -0.85        \cr
#' wt      \tab 0.78        \tab  1           \tab -0.87        \cr
#' mpg     \tab -0.85       \tab  -0.87       \tab 1            \cr
#' mean_sd \tab 6.19 (1.79) \tab  3.22 (0.98) \tab 20.09 (6.03)
#'}
#'
#' 3. Given obj and se, umxAPA returns a CI based on 1.96 times the se.
#' 
#' 4. Given only a number as obj will be treated as a p-value as returned in APA format.
#' 
#' @aliases summaryAPA
#' @param obj A model (e.g. \link{lm}, lme, glm, t-test), beta-value, or data.frame
#' @param se If obj is a beta, se treated as standard-error (returning a CI). 
#' If obj is a model, used to select effect of interest (blank for all effects). 
#' Finally, set se to the CI c(lower, upper), to back out the SE.
#' @param std Whether to report std betas (re-runs model on standardized data).
#' @param digits How many digits to round output.
#' @param use If obj is a data.frame, how to handle NAs (default = "complete")
#' @param min For a p-value, the smallest value to report numerically (default .001)
#' @param addComparison For a p-value, whether to add "</=" default (NA) adds "<" if necessary
#' @param report What to return (default = 'markdown'). Use 'html' to open a web table.
#' @param lower Whether to not show the lower triangle of correlations for a data.frame (Default TRUE)
#' @param SEs Whether or not to show correlations with their SE (Default TRUE)
#' @param means Whether or not to show means in a correlation table (Default TRUE)
#' @param test If obj is a glm, which test to use to generate p-values options = "Chisq", "LRT", "Rao", "F", "Cp"
#' @return - string
#' @export
#' @family Reporting Functions
#' @references - \url{https://github.com/tbates/umx}, \url{https://my.ilstu.edu/~jhkahn/apastats.html}
#' @examples
#' 
#' # ========================================
#' # = Report lm (regression/anova) results =
#' # ========================================
#' umxAPA(lm(mpg ~ wt + disp, mtcars)) # All parameters
#' umxAPA(lm(mpg ~ wt + disp, mtcars), "disp") # Just disp effect
#' umxAPA(lm(mpg ~ wt + disp, mtcars), std = TRUE) # Standardize effects
#' 
#' # glm example
#' df = mtcars
#' df$mpg_thresh = 0
#' df$mpg_thresh[df$mpg>16] = 1
#' m1 = glm(mpg_thresh ~ wt + gear,data = df, family = binomial)
#' umxAPA(m1)
#' 
#' # A t-Test
#' m1 = t.test(1:10, y = c(7:20))
#' umxAPA(m1)
#' 
#' # ========================================================
#' # = Summarize a DATA FRAME: Correlations + Means and SDs =
#' # ========================================================
#' umxAPA(mtcars[,1:3])
#' umxAPA(mtcars[,1:3], digits = 3)
#' umxAPA(mtcars[,1:3], lower = FALSE)
#' \dontrun{
#' umxAPA(mtcars[,1:3], report = "html")
#' }
#' 
#' # ===============================================
#' # = CONFIDENCE INTERVAL text from effect and se =
#' # ===============================================
#' umxAPA(.4, .3) # parameter 2 interpreted as SE
#' 
#' # Input beta and CI, and back out the SE
#' umxAPA(-0.030, c(-0.073, 0.013), digits = 3)
#' 
#' # ====================
#' # = Format a p-value =
#' # ====================
#' umxAPA(.0182613)
#' umxAPA(.000182613)
#' umxAPA(.000182613,  addComparison=FALSE)
#' 
#' # ========================
#' # = report a correlation =
#' # ========================
#' data(twinData)
#' selDVs = c("wt1", "wt2")
#' mzData <- subset(twinData, zygosity %in% c("MZFF", "MZMM"))
#' x = cor.test(~ wt1 + wt2, data = mzData)
#' umxAPA(x)
#'
umxAPA <- function(obj = .Last.value, se = NULL, std = FALSE, digits = 2, use = "complete", min = .001, addComparison = NA, report = c("markdown", "html"), lower = TRUE, test = c("Chisq", "LRT", "Rao", "F", "Cp"), SEs = TRUE, means = TRUE) {
	report = match.arg(report)
	test = match.arg(test)
	if("htest" == class(obj)[[1]]){
		o = paste0("r = ", round(obj$estimate, digits), " [", round(obj$conf.int[1], digits), ", ", round(obj$conf.int[2], digits), "]")
		o = paste0(o, ", t(", obj$parameter, ") = ", round(obj$statistic, digits),  ", p = ", umxAPA(obj$p.value))
		return(o)
	}else if("data.frame" == class(obj)[[1]]){
		# Generate a summary of correlation and means
		cor_table = umxHetCor(obj, ML = FALSE, use = use, treatAllAsFactor = FALSE, verbose = FALSE, std.err = SEs, return = "hetcor object")
		# cor_table = x; digits = 2
		# cor_table = umx_apply(FUN= round, of = cor_table, digits = digits) # round correlations
		correlations = round(cor_table$correlations, digits)
		if(SEs){
			std.errors = round(cor_table$std.errors, digits)
			correlations[] = paste0(as.character(correlations), " (", as.character(std.errors), ")")
		}
		cor_table = correlations

		if(lower){
			cor_table[upper.tri(cor_table)] = ""
		}

		if(means){
			mean_sd = umx_apply(umx_fun_mean_sd, of = obj)
			output  = data.frame(rbind(cor_table, mean_sd), stringsAsFactors = FALSE)
			rownames(output)[length(rownames(output))] = "Mean (SD)"
		} else {
			output  = data.frame(cor_table, stringsAsFactors = FALSE)
		}
		if(report == "html"){
			umx_print(output, digits = digits, file = "tmp.html")
		} else {
			umx_print(output, digits = digits)
		}
		if(anyNA(obj)){
			message("Some rows in dataframe had missing values.")
		}
	} else if("matrix" == class(obj)[[1]]) {
		# Assume these are correlations or similar numbers
		cor_table = umx_apply(round, obj, digits = digits) # round correlations
		output = data.frame(cor_table)
		if(report == "html"){
			umx_print(output, digits = digits, file = "tmp.html")
		} else {
			umx_print(output, digits = digits)
		}
	} else if("lm" == class(obj)[[1]]) {
		# report lm summary table
		if(std){
			obj = update(obj, data = umx_scale(obj$model))
		}
		model_coefficients = summary(obj)$coefficients
		conf = confint(obj)
		if(is.null(se)){
			se = dimnames(model_coefficients)[[1]]
		}
		for (i in se) {
			lower   = conf[i, 1]
			upper   = conf[i, 2]
			b_and_p = model_coefficients[i, ]
			b       = b_and_p["Estimate"]
			tval    = b_and_p["t value"]
			pval    = b_and_p["Pr(>|t|)"]
			print(paste0(i, " \u03B2 = ", round(b, digits), 
			   " [", round(lower, digits), ", ", round(upper, digits), "], ",
			   "t = ", round(tval, digits), ", p ", umx_APA_pval(pval, addComparison = TRUE)
			))		
		}
	} else if("glm" == class(obj)[[1]]) {
		# report glm summary table
		if(std){
			message("TODO: not sure how to not scale the DV in this gml")
			obj = update(obj, data = umx_scale(obj$model))
		}
		# TODO pick test based on family
		# Chisq = "binomial" "Poisson" (Chisq same as "LRT")
		# F = gaussian, quasibinomial, quasipoisson
		# Cp similar to AIC
		# see ?anova.glm 

		model_coefficients = summary(obj)$coefficients
		conf = confint(obj)

		if(is.null(se)){
			se = dimnames(model_coefficients)[[1]]
		}
		for (i in se) {
			lower   = conf[i, 1]
			upper   = conf[i, 2]
			b_and_p = model_coefficients[i, ]
			b       = b_and_p["Estimate"]
			testStat    = b_and_p["z value"]
			pval    = b_and_p["Pr(>|z|)"]
			print(paste0(i, " \u03B2 = ", round(b, digits), 
			   " [", round(lower, digits), ", ", round(upper, digits), "], ",
			   "z = ", round(testStat, digits), ", p ", umx_APA_pval(pval, addComparison = TRUE)
			))
		}
		print(paste0("AIC = ", round(AIC(obj), 3) ))
	} else if( "lme" == class(obj)[[1]]) {
		# report lm summary table
		if(std){
			obj = update(obj, data = umx_scale(obj$data))
		}
		model_coefficients = summary(obj)$tTable
		conf = intervals(obj, which = "fixed")[[1]]
		if(is.null(se)){
			se = dimnames(model_coefficients)[[1]]
		}
		for (i in se) {
			# umx_msg(i)
			lower   = conf[i, "lower"]
			upper   = conf[i, "upper"]
			b       = conf[i, "est."]
			tval    = model_coefficients[i, "t-value"]
			numDF   = model_coefficients[i, "DF"]
			pval    = model_coefficients[i, "p-value"]
			print(paste0(i, " \u03B2 = ", round(b, digits), 
			   " [", round(lower, digits), ", ", round(upper, digits), "], ",
			   "t(", numDF, ") = ", round(tval, digits), ", p ", umx_APA_pval(pval, addComparison = TRUE)
			))
		}
	} else {
		if(is.null(se)){
			# p-value
			umx_APA_pval(obj, min = min, digits = digits, addComparison = addComparison)
		} else if(length(se)==2){
			# beta and CI
			# lower = b - (1.96 * se)
			# upper = b + (1.96 * se)
			print(paste0("\u03B2 = ", round(obj, digits), ", se =", round((se[2] - se[1])/(1.96 * 2), digits)))
		} else {
			# obj = beta and SE
			print(paste0("\u03B2 = ", round(obj, digits), " [", round(obj - (1.96 * se), digits), ", ", round(obj + (1.96 * se), digits), "]"))
		}
	}
}

#' @export
summaryAPA <- umxAPA

#' Summarize twin data
#'
#' @description
#' Produce a summary of wide-format twin data, showing the number of individuals, the mean and SD for each trait, and the correlation for each twin-type.
#'
#' Set MZ and DZ to summarize the two-group case.
#' 
#' @param data The twin data.
#' @param selVars Collection of variables to report on, e.g. c("wt", "ht").
#' @param sep  The separator string that will turn a variable name into a twin variable name, e.g. "_T" for wt_T1 and wt_T2.
#' @param zyg  The zygosity variable in the dataset, e.g. "zygosity".
#' @param MZ Set level in zyg corresponding to MZ for two group case (defaults to using 5-group case).
#' @param DZ Set level in zyg corresponding to DZ for two group case (defaults to using 5-group case).
#' @param MZFF The level in zyg corresponding to MZ FF pairs: e.g., "MZFF".
#' @param DZFF The level in zyg corresponding to DZ FF pairs: e.g., "DZFF".
#' @param MZMM The level in zyg corresponding to MZ MM pairs: e.g., "MZMM".
#' @param DZMM The level in zyg corresponding to DZ MM pairs: e.g., "DZMM".
#' @param DZOS The level in zyg corresponding to DZ OS pairs: e.g., "DZOS".
#' @param digits Rounding precision of the report (default 2).
#' @return - formatted table, e.g. in markdown.
#' @export
#' @family Twin Reporting Functions
#' @seealso - \code{\link{umxAPA}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' data(twinData)
#' umxSummarizeTwinData(twinData, sep = "", selVars = c("wt", "ht"))
#' MZs = c("MZMM", "MZFF"); DZs = c("DZFF","DZMM", "DZOS")
#' umxSummarizeTwinData(twinData, sep = "", selVars = c("wt", "ht"), MZ = MZs, DZ = DZs)
umxSummarizeTwinData <- function(data = NULL, selVars = "wt", sep = "_T", zyg = "zygosity", MZ = NULL, DZ = NULL, MZFF= "MZFF", DZFF= "DZFF", MZMM= "MZMM", DZMM= "DZMM", DZOS= "DZOS", digits = 2) {
	# TODO cope with two group case.
	# data = twinData; selVars = c("wt", "ht"); zyg = "zygosity"; sep = ""; digits = 2
	selDVs = tvars(selVars, sep)
	umx_check_names(selDVs, data = data, die = TRUE)
	long = umx_wide2long(data= data[,selDVs], sep =sep)
	blob = rep(NA, length(selVars))	
	if(is.null(MZ)){
		df = data.frame(Var = blob, Mean = blob, SD = blob, rMZFF = blob, rMZMM = blob, rDZFF = blob, rDZMM = blob, rDZOS = blob, stringsAsFactors = FALSE)
		n = 1
		for (varName in selVars){
			# varName = "ht"
			df[n, "Var"]  = varName
			df[n, "Mean"] = round(mean(long[,varName], na.rm = TRUE), digits)
			df[n, "SD"]   = round(sd(long[,varName], na.rm = TRUE), digits)
			rMZFF = cor.test(data = data[data[,zyg] %in% MZFF,], as.formula(paste0("~ ", varName, sep, 1, "+", varName, sep, 2)))
			rMZMM = cor.test(data = data[data[,zyg] %in% MZMM,], as.formula(paste0("~ ", varName, sep, 1, "+", varName, sep, 2)))
			rDZFF = cor.test(data = data[data[,zyg] %in% DZFF,], as.formula(paste0("~ ", varName, sep, 1, "+", varName, sep, 2)))
			rDZMM = cor.test(data = data[data[,zyg] %in% DZMM,], as.formula(paste0("~ ", varName, sep, 1, "+", varName, sep, 2)))
			rDZOS = cor.test(data = data[data[,zyg] %in% DZOS,], as.formula(paste0("~ ", varName, sep, 1, "+", varName, sep, 2)))

			df[n, "rMZFF"] = paste0(round(rMZFF$estimate, digits), " (", round((rMZFF$conf.int[2] - rMZFF$conf.int[1])/(1.96 * 2), digits), ")")
			df[n, "rMZMM"] = paste0(round(rMZMM$estimate, digits), " (", round((rMZMM$conf.int[2] - rMZMM$conf.int[1])/(1.96 * 2), digits), ")")
			df[n, "rDZFF"] = paste0(round(rDZFF$estimate, digits), " (", round((rDZFF$conf.int[2] - rDZFF$conf.int[1])/(1.96 * 2), digits), ")")
			df[n, "rDZMM"] = paste0(round(rDZMM$estimate, digits), " (", round((rDZMM$conf.int[2] - rDZMM$conf.int[1])/(1.96 * 2), digits), ")")
			df[n, "rDZOS"] = paste0(round(rDZOS$estimate, digits), " (", round((rDZOS$conf.int[2] - rDZOS$conf.int[1])/(1.96 * 2), digits), ")")
			n = n+1
		}
		nPerZyg = table(data[, zyg])
		names(df) = namez(df, "(rMZFF)", paste0("\\1 (", nPerZyg["MZFF"],")"))
		names(df) = namez(df, "(rDZFF)", paste0("\\1 (", nPerZyg["DZFF"],")"))
		names(df) = namez(df, "(rMZMM)", paste0("\\1 (", nPerZyg["MZMM"],")"))
		names(df) = namez(df, "(rDZMM)", paste0("\\1 (", nPerZyg["DZMM"],")"))
		names(df) = namez(df, "(rDZOS)", paste0("\\1 (", nPerZyg["DZOS"],")"))
	}else{
		df = data.frame(Var = blob, Mean = blob, SD = blob, rMZ = blob, rDZ = blob, stringsAsFactors = FALSE)		
		n = 1
		for (varName in selVars){
			# varName = "ht"
			df[n, "Var"]  = varName
			df[n, "Mean"] = round(mean(long[,varName], na.rm = TRUE), digits)
			df[n, "SD"]   = round(sd(long[,varName], na.rm = TRUE), digits)
			rMZ = cor.test(data = data[data[,zyg] %in% MZ,], as.formula(paste0("~ ", varName, sep, 1, "+", varName, sep, 2)))
			rDZ = cor.test(data = data[data[,zyg] %in% DZ,], as.formula(paste0("~ ", varName, sep, 1, "+", varName, sep, 2)))
			df[n, "rMZ"] = paste0(round(rMZ$estimate, digits), " (", round((rMZ$conf.int[2] - rMZ$conf.int[1])/(1.96 * 2), digits), ")")
			df[n, "rDZ"] = paste0(round(rDZ$estimate, digits), " (", round((rDZ$conf.int[2] - rDZ$conf.int[1])/(1.96 * 2), digits), ")")
			n = n+1
		}
		nPerZyg = data.frame(table(data[, zyg]))
		names(df) = namez(df, "(rMZ)", paste0("\\1 (", sum(nPerZyg[nPerZyg$Var1 %in% MZ,"Freq"]),")"))
		names(df) = namez(df, "(rDZ)", paste0("\\1 (", sum(nPerZyg[nPerZyg$Var1 %in% DZ,"Freq"]),")"))
	}
	umx_print(df)
	# return(df)
	# Calculate Mean Age and SD for men and women
	# umx_aggregate(value ~ Sex, data = longformat, what = "mean_sd")
	
	# Calculate correlations, means and sd Generativity
	# umxAPA(mzData[, allItemNames], use ="pairwise.complete.obs")
	# umxAPA(dzData[, allItemNames], use ="pairwise.complete.obs")
}

#' umx_APA_model_CI
#'
#' Look up CIs for free parameters in a model, and return as APA-formatted text string
#'
#' @param model an \code{\link{mxModel}} to get CIs from
#' @param cellLabel the label of the cell to interrogate for a CI, e.g. "ai_r1c1"
#' @param prefix The submodel to look in (i.e. "top.")
#' @param suffix The suffix for algebras ("_std")
#' @param SEstyle report "b (se)" instead of b CI95[l,u] (default = FALSE)
#' @param digits = 2
#' @param verbose = FALSE
#' @return - the CI string, e.g. ".73[-.20, .98]" or .73(.10)
#' @export
#' @family Reporting Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' \dontrun{
#' umx_APA_model_CI(fit_IP, cellLabel = "ai_r1c1", prefix = "top.", suffix = "_std")
#' }
umx_APA_model_CI <- function(model, cellLabel, prefix = "top.", suffix = "_std", digits = 2, SEstyle = FALSE, verbose= FALSE){
	# TODO umx_APA_model_CI add choice of separator for CI
	#      stash this as a preference
	# TODO alias umx_APA_model_CI to umx_get_CI
	if(!umx_has_CIs(model)){
		if(verbose){
			message("no CIs")
		}
		return(NA)
	} else {
		# We want "top.ai_std[1,1]" from "ai_r1c1"
		result = tryCatch({
			grepStr = '^(.*)_r([0-9]+)c([0-9]+)$' # 1 = matrix names, 2 = row, 3 = column
			mat = sub(grepStr, '\\1', cellLabel, perl = TRUE);
			row = sub(grepStr, '\\2', cellLabel, perl = TRUE);
			col = sub(grepStr, '\\3', cellLabel, perl = TRUE);
			# prefix = "top."
			CIlist      = model$output$confidenceIntervals
			dimIndex    = paste0(prefix, mat, suffix, "[", row, ",", col, "]")
			dimNoSuffix = paste0(prefix, mat, "[", row, ",", col, "]")

			intervalNames = dimnames(CIlist)[[1]]
			if(dimIndex %in% intervalNames){
				check = dimIndex
			} else {
				check = dimNoSuffix
			}
			if(SEstyle){
				est = CIlist[check, "estimate"]
				if(is.na(CIlist[check, "lbound"])){
					# no lbound found: use ubound to form SE (SE not defined if ubound also NA :-(
					DIFF = (CIlist[check, "ubound"] - est)
				} else if (is.na(CIlist[check, "ubound"])){
					# lbound, but no ubound: use lbound to form SE
					DIFF = (est - CIlist[check, "lbound"])
				}else{
					# Both bounds present: average to get an SE
					DIFF = mean(c( (CIlist[check, "ubound"] - est), (est - CIlist[check, "lbound"]) ))
				}
			   APAstr = paste0(round(est, digits), " (", round(DIFF/(1.96 * 2), digits), ")")
			} else {
			   APAstr = paste0(
				umx_APA_pval(CIlist[check, "estimate"], min = -1, digits = digits), "[",
				umx_APA_pval(CIlist[check, "lbound"], min = -1, digits = digits)  , ",",
				umx_APA_pval(CIlist[check, "ubound"], min = -1, digits = digits)  , "]"
			   )
			}
		    return(APAstr) 
		}, warning = function(cond) {
			if(verbose){
				message(paste0("warning ", cond, " for CI ", omxQuotes(cellLabel)))
			}
		    return(NA) 
		}, error = function(cond) {
			if(verbose){
				message(paste0("error: ", cond, " for CI ", omxQuotes(cellLabel), "\n",
				"dimIndex = ", dimIndex))
				print(intervalNames)
			}
		    return(NA) 
		}, finally = {
		    # cleanup-code
		})
		return(result)
	}
	# if estimate differs...
}

#' Test the difference between correlations for significance.
#'
#' @description
#' umx_r_test is a wrapper around the cocor test of difference between correlations.
#'
#' @details
#' Currently it handles the test of whether r.jk and r.hm differ in magnitude.
#' i.e, two non-overlapping (no variable in common) correlations in the same dataset.
#' In the future it will be expanded to handle overlapping correlations, and to take correlation matrices as input.
#'
#' @param data the dataset
#' @param vars the 4 vars needed: "j & k" and "h & m"
#' @param alternative two (default) or one-sided (greater less) test
#' @return - 
#' @export
#' @family Miscellaneous Stats Helpers
#' @examples
#' vars = c("mpg", "cyl", "disp", "hp")
#' umx_r_test(mtcars, vars)
umx_r_test <- function(data = NULL, vars = vars, alternative = c("two.sided", "greater", "less")) {
	alternative = match.arg(alternative)
	test         = "silver2004"
	alpha        = 0.05
	conf.level   = 0.95
	null.value   = 0
	data.name    = NULL
	var.labels   = NULL
	return.htest = FALSE
	jkhm = data[, vars]
	cors = cor(jkhm)
	# jkhm = 1234
	r.jk = as.numeric(cors[vars[1], vars[2]])
	r.hm = as.numeric(cors[vars[3], vars[4]])
	r.jh = as.numeric(cors[vars[1], vars[3]])
	r.jm = as.numeric(cors[vars[1], vars[4]])
	r.kh = as.numeric(cors[vars[2], vars[3]])
	r.km = as.numeric(cors[vars[2], vars[4]])
	n = nrow(jkhm)	
	cocor::cocor.dep.groups.nonoverlap(r.jk, r.hm, r.jh, r.jm, r.kh, r.km, n, alternative = alternative, test = test, alpha = alpha, conf.level = conf.level, null.value = null.value, data.name = data.name, var.labels = var.labels, return.htest = return.htest)
}
