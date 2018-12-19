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

# ==================
# = Model Builders =
# ==================

#' FIML-based Exploratory Factor Analysis (EFA)
#'
#' Perform full-information maximum-likelihood factor analysis on a data matrix.
#' 
#' As in \code{\link{factanal}}, you need only specify the number of factors and offer up
#' some manifest data, e.g:
#'                                                              
#' \code{umxEFA(factors = 2, data = mtcars)}
#' 
#' Equivalently, you can also give a list of factor names:
#' 
#' \code{umxEFA(factors = c("g", "v"), data = mtcars)}
#' 
#' The factor model is implemented as a structural equation model, e.g.
#' 
#'
#' \if{html}{\figure{umxEFA.png}{options: width="50\%" alt="Figure: umxEFA.png"}}
#' \if{latex}{\figure{umxEFA.pdf}{options: width=7cm}}
#' 
#' You can request \code{scores} from the model. Unlike factanal, these can cope with missing data.
#' 
#' You can also rotate the factors using any rotation function.
#' 
#' @details
#' In an EFA, all items may load on all factors.
#' 
#' For identification we need m^2 degrees of freedom. We get m * (m+1)/2 from fixing factor variances to 1 and covariances to 0.
#' We get another m(m-1)/2 degrees of freedom by fixing the upper-right hand corner of the factor loadings
#' component of the A matrix. The manifest variances are also lbounded at 0.
#' 
#' EFA reports standardized loadings: to do this, we scale the data.
#' 
#' \emph{note}: Bear in mind that factor scores are indeterminate.
#' 
#' Thanks to @ConorDolan for code implementing the rotation matrix and other suggestions!
#' 
#' 
#' @aliases umxFactanal umxEFA
#' @param x Either 1: data, 2: A formula (not implemented yet), 3: A vector of variable names, or 4: A name for the model.
#' @param factors Either number of factors to request or a vector of factor names.
#' @param data A dataframe of manifest columns you are modeling
#' @param n.obs Number of observations in covmat (if provided, default = NA)
#' @param rotation A rotation to perform on the loadings (default  = "varimax" (orthogonal))
#' @param scores Type of scores to produce, if any. The default is none, "Regression" gives Thompson's scores. Other options are 'ML', 'WeightedML', Partial matching allows these names to be abbreviated.
#' @param minManifests The least number of variables required to return a score for a participant (Default = NA).
#' @param name A name for your model
#' @param digits rounding (default = 2)
#' @param return by default, the resulting MxModel is returned. Say "loadings" to get a fact.anal object.
#' @param report Report as markdown to the console, or open a table in browser ("html")
#' @param covmat Covariance matrix of data you are modeling (not implemented)
#' @return - EFA \code{\link{mxModel}}
#' @family Super-easy helpers
#' @export
#' @seealso - \code{\link{factanal}}, \code{\link{mxFactorScores}}
#' @references - \url{https://github.com/tbates/umx}
#' @examples
#' \dontrun{
#' myVars <- c("mpg", "disp", "hp", "wt", "qsec")
#' m1 = umxEFA(mtcars[, myVars], factors =   2, rotation = "promax")
#' loadings(m1)
#' 
#' # Formula interface in base-R factanal()
#' m2 = factanal(~ mpg + disp + hp + wt + qsec, factors = 2, rotation = "promax", data = mtcars)
#' loadings(m2)
#' plot(m2)
#' 
#' # Return a loadings object
#' x = umxEFA(mtcars[, myVars], factors = 2, return = "loadings")
#' names(x)
#' 
#' m1 = umxEFA(myVars, factors = 2, data = mtcars, rotation = "promax")
#' m1 = umxEFA(name = "named", factors = "g", data = mtcars[, myVars])
#' m1 = umxEFA(name = "by_number", factors = 2, rotation = "promax", data = mtcars[, myVars])
#' x = umxEFA(name = "score", factors = "g", data = mtcars[, myVars], scores= "Regression")
#' }
umxEFA <- function(x = NULL, factors = NULL, data = NULL, n.obs = NULL, 
	scores = c("none", 'ML', 'WeightedML', 'Regression'), minManifests = NA,
	rotation = c("varimax", "promax", "none"), name = "efa", digits = 2, return = c("model", "loadings"), report = c("markdown", "html"), covmat = NULL){
	# TODO: umxEFA: Detect ordinal items and switch to UWLS
	rotation = umx_default_option(rotation, c("varimax", "promax", "none"), check = FALSE)
	scores   = match.arg(scores)
	return   = match.arg(return)

	# "Bartlett" given Bartlett's weighted least-squares scores. 
	# name     = "efa"
	# factors  = 1
	# data     = mtcars[,c("mpg", "disp", "hp", "wt", "qsec")]
	# rotation = "varimax"
	if (!is.null(data)){
		# x must be formula, or column list && covmat and n.obs must be NULL
		if(!is.null(covmat) || !is.null(n.obs)){
			stop("covmat and n.obs must be empty when using 'data =' ...")
		}
		if(!is.null(x)){
			if (inherits(x,"formula")){
				if(is.null(data)){
					stop(paste("If you provide a formula in x to select variable, data must contain a dataframe"))
				} else {
					x = all.vars(x)
					data = data[, x]
					name = "EFA"
				}
			} else if(length(x) > 1) {
				umx_check_names(x, data)
				data = data[,x]
				name = "EFA"
			}else{
				name = x
			}
		}else{
			name = "EFA"
		}
	} else if(!is.null(covmat) || !is.null(n.obs)){
		# data must be NULL
		stop("With cov data, you may as well be using factanal()...")
		if(!is.null(data)){
			stop("You can't offer up both a data.frame and a covmat.")
		}
	} else {
		# data is empty, so x must be data
		if(!is.null(x)){
			if(is.data.frame(x)){
				data = x # get data from x
			}else if (is.matrix(x)){
				data = as.data.frame(x)
			}
		} else if(is.null(data)){
			stop("You need to provide a data.frame to analyse: this can be in x, or data, or covmat")
		}
		name = "EFA"
	}

	# TODO: umxEFA scale data - What about for scores? Do we want std loadings in that case?...
	data = umx_scale(data)
	if(is.null(factors)){
		stop("You need to request at least 1 latent factor, e.g.: factors = 4")
	} else if( length(factors) == 1 && class(factors) == "numeric"){
		factors = paste0("F", c(1:factors))
	}else{
		# factors is a list of factor names (we hope)
	}
	# TODO umxEFA: Adapt to input datatype, i.e., add cov handler
	# umx_print(factors)
	manifests <- names(data)
	m1 <- umxRAM(model = name, data = data, autoRun = FALSE,
		umxPath(factors, to = manifests, connect = "unique.bivariate"),
		umxPath(v.m. = manifests),
		umxPath(v1m0 = factors)
	)
	# Fix upper-right triangle of A-matrix factor columns at zero
	nFac       = length(factors)
	nManifests = length(manifests)
	if(nFac > 1){
		for(i in 2:nFac){
			m1$A$free[1:(i-1)  , factors[i]] = FALSE
			m1$A$values[1:(i-1), factors[i]] = 0
		}
	}
	# lbound the manifest diagonal to avoid mirror indeterminacy
	for(i in seq_along(manifests)) {
	   thisManifest = manifests[i]
	   m1$A$lbound[thisManifest, thisManifest] = 0
	}
	m1 = mxRun(m1)
	if(rotation != "none" && nFac > 1){
		x = loadings.MxModel(m1)
		x = eval(parse(text = paste0(rotation, "(x)")))
		print("Rotation results")
		print(x) # print out the nice rotation result
		rm = x$rotmat
		print("Factor Correlation Matrix")
		print(solve(t(rm) %*% rm))

		# stash the rotated result in the model A matrix
		m1$A$values[manifests, factors] = x$loadings[1:nManifests, 1:nFac] 
	} else {
		print("Results")
		print(loadings(m1))
	}
	umxSummary(m1, digits = digits, report = report);
	if(scores != "none"){
		x = umxFactorScores(m1, type = scores, minManifests = minManifests)
	} else {
		if(return == ""){
			invisible(x)
		} else {
			invisible(m1)
		}
	}
}

#' @export
umxFactanal <- umxEFA

#' Return factor scores from a model as an easily consumable dataframe.
#' @description
#' umxFactorScores takes a model, and computes factors scores using the selected method (one 
#' of 'ML', 'WeightedML', or 'Regression')
#' It is a simple wrapper around mxFactorScores. For missing data, you must specify the least number of 
#' variables allowed for a score (subjects with fewer than minManifests will return a score of NA.
#' @param model The model to generate scores from.
#' @param type  The method used to compute the score ('ML', 'WeightedML', or 'Regression').
#' @param minManifests The least number of variables required to return a score for a participant (Default = NA).
#' @return - dataframe of scores.
#' @export
#' @family Reporting Functions
#' @seealso - \code{\link{mxFactorScores}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' m1 = umxEFA(mtcars, factors = 2)
#' x = umxFactorScores(m1, type = c('Regression'), minManifests = 3)
#' \dontrun{
#' m1 = umxEFA(mtcars, factors = 1)
#' x = umxFactorScores(m1, type = c('Regression'), minManifests = 3)
#' x
#' }
umxFactorScores <- function(model, type = c('ML', 'WeightedML', 'Regression'), minManifests = NA) {
	suppressMessages({
		scores = mxFactorScores(model, type = type, minManifests = minManifests)
	})
	# Only need score from [nrow, nfac, c("Scores", "StandardErrors")]
	if(dim(scores)[2] == 1){
		# drop = FALSE if only 1 factor
		out = scores[ , 1, "Scores"]
		out = data.frame(out)
		names(out) <- dimnames(scores)[[2]]
		return(out)
	} else {
		return(scores[ , , 1])
	}
}


#' umxTwoStage
#'
#' umxTwoStage implements 2-stage least squares regression in Structural Equation Modeling.
#' For ease of learning, the function is modeled closely on the \code{\link[sem]{tsls}}.
#' 
#' The example is a Mendelian Randomization \url{https://en.wikipedia.org/wiki/Mendelian_randomization} 
#' analysis to show the utility of two-stage regression.
#'
#' @param formula	The structural equation to be estimated; a regression constant is implied if not explicitly omitted.
#' @param instruments	A one-sided formula specifying instrumental variables.
#' @param data data.frame containing the variables in the model.
#' @param subset [optional] vector specifying a subset of observations to be used in fitting the model.
#' @param weights [optional] vector of weights to be used in the fitting process;
#' If specified should be a non-negative numeric vector with one entry for each observation,
#' to be used to compute weighted 2SLS estimates.
#' @param contrasts	an optional list. See the contrasts.arg argument of model.matrix.default.
#' @param name for the model (defaults to "tsls")
#' @param ...	arguments to be passed down.
#' @return - 
#' @export
#' @family Super-easy helpers
#' @seealso - \code{\link{umx_make_MR_data}}, \code{\link[sem]{tsls}}, \code{\link{umxRAM}}
#' @references - Fox, J. (1979) Simultaneous equation models and two-stage least-squares.
#' In Schuessler, K. F. (ed.) \emph{Sociological Methodology}, Jossey-Bass., 
#' Greene, W. H. (1993) \emph{Econometric Analysis}, Second Edition, Macmillan.
#' @examples
#' library(umx)
#' 
#' 
#' # ====================================
#' # = Mendelian randomization analysis =
#' # ====================================
#' 
#' # Note: in practice: many more subjects are desirable - this just to let example run fast
#' df = umx_make_MR_data(1000) 
#' m1 = umxTwoStage(Y ~ X, instruments = ~ qtl, data = df)
#' parameters(m1)
#' plot(m1)
#' 
#' # Errant analysis using ordinary least squares regression (WARNING this result is CONFOUNDED!!)
#' m1 = lm(Y ~ X    , data = df); coef(m1) # incorrect .35 effect of X on Y
#' m1 = lm(Y ~ X + U, data = df); coef(m1) # Controlling U reveals the true 0.1 beta weight
#' #
#' #
#' \dontrun{
#' df = umx_make_MR_data(1e5) 
#' m1 = umxTwoStage(Y ~ X, instruments = ~ qtl, data = df)
#' 
#' # ======================
#' # = Now with sem::tsls =
#' # ======================
#' # library(sem) # will require you to install X11
#' m2 = sem::tsls(formula = Y ~ X, instruments = ~ qtl, data = df)
#' coef(m1)
#' coef(m2)
# # Try with missing value for one subject: A benefit of the FIML approach in OpenMx.
#' m3 = tsls(formula = Y ~ X, instruments = ~ qtl, data = (df[1, "qtl"] = NA))
#' }
umxTwoStage <- function(formula, instruments, data, subset, weights, contrasts= NULL, name = "tsls", ...) {
	umx_check(is.null(contrasts), "stop", "Contrasts not supported yet in umxTwoStage: email maintainer to prioritize")	
	# formula = Y ~ X; instruments ~ qtl; data = umx_make_MR_data(10000)
	# m1 = sem::tsls(formula = Y ~ X, instruments = ~ qtl, data = df)
	# summary(sem::tsls(Q ~ P + D, ~ D + F + A, data=Kmenta))
	if(!class(formula) == "formula"){
		stop("formula must be a formula")
	}
	allForm = all.vars(terms(formula))
	if(length(allForm) != 2){
		stop("I'm currently limited to 1 DV, 1 IV, and 1 instrument: 'formula' had ", length(allForm), " items")
	}
	DV   = allForm[1] # left hand item
	Xvars  = all.vars(delete.response(terms(formula)))
	inst = all.vars(terms(instruments))
	if(length(inst) != 1){
		stop("I'm currently limited to 1 DV, 1 IV, and 1 instrument: 'instruments' had ", length(allForm), " items")
	}
	manifests <- c(allForm, inst)     # manifests <- c("qtl", "X", "Y")
	latentErr <- paste0("e", allForm) # latentErr   <- c("eX", "eY")
	umx_check_names(manifests, data = data, die = TRUE)

	IVModel <- umxRAM("IV Model", data = data,
		# Causal and confounding paths
		umxPath(inst , to = Xvars), # beta of SNP effect          :  X ~ b1 x inst
		umxPath(Xvars, to = DV),    # Causal effect of Xvars on DV: DV ~ b2 x X

		# Latent error stuff + setting up variance and means for variables
		umxPath(v.m. = inst),     # Model variance and mean of instrument
		umxPath(var = latentErr), # Variance of residual errors
		umxPath(latentErr, to = allForm, fixedAt = 1), # X and Y residuals@1.
		umxPath(unique.bivariate = latentErr, values = 0.2, labels = paste0("phi", length(latentErr)) ), # Correlation among residuals
		umxPath(means = c(Xvars, DV))
	)
	# umx_time(IVModel) # IV Model: 3.1 s ( was 14.34 seconds with poor start values) for 100,000 subjects
	return(IVModel)
}

# load(file = "~/Dropbox/shared folders/OpenMx_binaries/shared data/bad_CFI.Rda", verbose =T)
# ref <- mxRefModels(IVModel, run=TRUE)
# summary(IVModel, refModels=ref)