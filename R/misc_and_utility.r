#' Helper to make a graphviz rank string
#'
#' @description
#' Helper to make a graphviz rank string is a function which 
#'
#' @param vars a list of strings
#' @param pattern regular expression to filter vars
#' @param rank "same", max, min
#' @return string
#' @export
#' @family Miscellaneous Utility Functions
#' @seealso - \code{\link{umxLabel}}
#' @examples
#' umx_graphviz_rank(c("as1"), "^[ace]s[0-9]+$", "same")
umx_graphviz_rank <- function(vars, pattern, rank) {
	formatted = paste(namez(vars, pattern), collapse = "; ")
	ranks = paste0("{rank=", rank, "; ", formatted, "};\n")
	return(ranks)
}

#' Return whether a cell is in a set location of a matrix
#'
#' @description
#' Helper to determine is a cell is in a set location of a matrix or not.
#' Left is useful for, e.g. twin means matrices.
#' @param r which row the cell is on.
#' @param c which column the cell is in.
#' @param where the location (any, diag, lower or upper or left).
#' @param mat (optionally) provide matrix to check dimensions against r and c.
#' @return - \code{\link{mxModel}}
#' @export
#' @family Miscellaneous Utility Functions
#' @seealso - \code{\link{umxLabel}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' umx_cell_is_on(r = 3, c = 3, "lower")
#' umx_cell_is_on(r = 3, c = 3, "upper")
#' umx_cell_is_on(r = 3, c = 3, "diag")
#' umx_cell_is_on(r = 2, c = 3, "diag")
#' umx_cell_is_on(r = 3, c = 3, "any")
#' a_cp = umxMatrix("a_cp", "Lower", 3, 3, free = TRUE, values = 1:6)
#' umx_cell_is_on(r = 3, c = 3, "left", mat = a_cp)
#' \dontrun{
#' # test stopping
#' umx_cell_is_on(r=4,c = 3, "any", mat = a_cp)
#' }
umx_cell_is_on <- function(r, c, where=c("diag", "lower", "upper", "any", "left"), mat= NULL) {
	where = match.arg(where)
	if(!is.null(mat)){
		# check r and c in bounds.
		if(r > dim(mat)[1]){
			stop("r is greater than size of matrix: ", dim(mat)[1])
		}
		if(c > dim(mat)[2]){
			stop("c is greater than size of matrix: ", dim(mat)[2])
		}
	}
	if(where =="any"){
		valid = TRUE
	} else if(where =="left"){
		if(is.null(mat)){
			stop("matrix must be offered up to check for begin on the left")
		}
		if(c <= dim(mat)[2]/2){
			valid = TRUE
		} else {
			valid = FALSE
		}
	} else if(where =="diag"){
		if(r == c){
			valid = TRUE
		} else {
			valid = FALSE
		}
	} else if(where =="lower"){
		if(r > c){
			valid = TRUE
		} else {
			valid = FALSE
		}
	} else if(where =="upper"){
		if(c > r){
			valid = TRUE
		} else {
			valid = FALSE
		}
	}else{
		stop("Where must be one of all, diag, lower, or upper. You gave me:", omxQuotes(where))
	}
	return(valid)
}

#' Return dot code for paths in a matrix
#'
#' @description
#' Return dot code for paths in a matrix is a function which 
#' Walk rows and cols of matrix. At each free cell, 
#' Create a string like:
#' 	ai1 -> var1 [label=".35"]
#' A latent (and correlations among latents)
#' 	* these go from a_cp n=row TO common n= row
#' 	* or for off diag, from a_cp n=col TO a_cp n= row
#'
#' @param x a \code{\link{umxMatrix}} to make paths from.
#' @param from one of "rows", "columns" or a name
#' @param cells which cells to proceess: "any" (default), "diag", "lower", "upper". "left" is the left half (e.g. in a twin means matrix)
#' @param arrows "forward" "both" or "back"
#' @param fromLabel = NULL
#' @param toLabel = NULL
#' @param selDVs if not null, row is used to index into this to set target name
#' @param showFixed = FALSE
#' @param digits rounding values (default = 2).
#' @param type one of "latent" or "manifest" (default NULL, don't accumulate new names using "from" list)
#' @param p input to build on. list(str = "", latents = c(), manifests = c())
#' @return - list(str = "", latents = c(), manifests = c())
#' @export
#' @family Miscellaneous Utility Functions
#' @seealso - \code{\link{plot}}
#' @examples
#' # Make a lower 3*3 value= 1:6 (1,4,6 on the diag)
#' a_cp = umxMatrix("a_cp", "Lower", 3, 3, free = TRUE, values = 1:6)
#' out = umx_mat2dot(a_cp, cells = "lower", from = "rows", arrows = "both")
#' cat(out$str)
#' out = umx_mat2dot(a_cp, cells = "lower", from = "cols", arrows = "both")
#' cat(out$str)
#' # First call also inits the plot struct
#' out = umx_mat2dot(a_cp, from = "rows", cells = "lower", arrows = "both", type = "latent")
#' out = umx_mat2dot(a_cp, from = "rows", cells = "diag" , toLabel= "common", type = "latent", p = out)
#' cat(out$str)
#' 
umx_mat2dot <- function(x, cells = c("any", "diag", "lower", "upper", "left"), from = "rows", fromLabel = NULL, toLabel = NULL, selDVs = NULL, showFixed = FALSE, arrows = c("forward", "both", "back"), type = NULL, digits = 2, p = list(str = "", latents = c(), manifests = c())) {
	cells  = match.arg(cells)
	arrows = match.arg(arrows)
	nRows = nrow(x)
	nCols = ncol(x)
	# Allow from and to labels other than the matrix name (default)
	if(is.null(fromLabel)){
		fromLabel = x$name
	}
	if(is.null(toLabel)){
		toLabel = x$name
	}
	 
	for (r in 1:nRows) {
		for (c in 1:nCols) {
			if(umx_cell_is_on(r= r, c = c, where = cells, mat = x)){
				# TODO get the CI (or should we rely on stashed CIs?)
				# TODO add this code to umx_mat2dot (need to pass in the model)
				# CIstr = umx_APA_model_CI(model, cellLabel = thisParam, prefix = "top.", suffix = "_std", digits = digits)
				# if(is.na(CIstr)){
				# 	val = umx_round(parameterKeyList[thisParam], digits)
				# }else{
				# 	val = CIstr
				# }
				value = round(x$values[r,c], digits)
				if(from == "rows"){
					if(fromLabel=="one"){
						fr = fromLabel
					} else {
						fr = paste0(fromLabel, r)
					}
					if(!is.null(selDVs)){
						tu = selDVs[c]
					}else{
						tu = paste0(toLabel, c)
					}
				} else { 
					if(fromLabel=="one"){
						fr = fromLabel
					} else {
						fr = paste0(fromLabel, c)
					}
					if(!is.null(selDVs)){
						tu = selDVs[r]
					}else{
						tu = paste0(toLabel, r)
					}
				}
				# Show fixed cells if non-0
				if(x$free[r,c] || (showFixed && x$values[r,c] != 0)){
					p$str = paste0(p$str, "\n", fr, " -> ", tu, " [dir = ", arrows, " label=\"", value, "\"];")
					if(!is.null(type)){
						if(type == "latent"){
							p$latents   = c(p$latents, fr)
						} else if(type == "manifest"){
							p$manifests = c(p$manifests, fr)
						}
					}
				}
			} else {
				# fixed cell
			}
		}
	}
	p$latents = unique(p$latents)
	p$manifests = unique(p$manifests)	
	p
}

# Poems one should know by heart:

# William Shakespeare
# [Tomorrow and tomorrow soliloquy](https://www.poetryfoundation.org/poems/56964/speech-tomorrow-and-tomorrow-and-tomorrow)
# [To be or not to be](https://www.poetryfoundation.org/poems/56965/speech-to-be-or-not-to-be-that-is-the-question)
# [The Merchant of Venice](https://www.goodreads.com/work/quotes/2682703-the-merchant-of-venice)
#  * "How far that little candle throws his beams! So shines a good deed in a weary world."
#  * The quality of mercy is not strained.
#  * "One half of me is yours, the other half is yours,
#    Mine own, I would say; but if mine, then yours,
#    And so all yours."
#  * If to do were as easy as to know what were good to do, chapels 
#    had been churches, and poor men's cottages princes’ palaces.
# * “This above all: to thine own self be true,

# # PERCY BYSSHE SHELLEY
# [Ozymandias](https://www.poetryfoundation.org/poems/46565/ozymandias)

# Brevia
#  * [Invictus](https://en.wikipedia.org/wiki/Invictus)
#  * [Abou ben Adhem](https://www.poetryfoundation.org/poems/44433/abou-ben-adhem)
#  * [Odi et amo](https://en.wikipedia.org/wiki/Catullus_85)

# # [Yeats](https://en.wikipedia.org/wiki/W._B._Yeats)
#  * [The Second Coming](https://en.wikipedia.org/wiki/The_Second_Coming_(poem))


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

# devtools::document("~/bin/umx"); devtools::install("~/bin/umx");
# utility naming convention: "umx_" prefix, lowercase, and "_" not camel case for word boundaries
# so umx_swap_a_block()

# ===================
# = OpenMx wrappers =
# ===================

#' A recipe Easter-egg for umx
#'
#' @description
#' How to cook steak.
#' @details Equipment matters. You should buy a heavy cast-iron skillet, and a digital internal thermometer.
#' Preferably cook over a gas flame.
#' 
#' *note*: Cheaper cuts like blade steak can come out fine.
#' 
#' A great reference is The Food Lab by Kenji Alt Lopez. https://www.amazon.co.uk/Food-Lab-Cooking-Through-Science/dp/0393081087.
#'
#' @export
#' @family Miscellaneous Utility Functions
#' @seealso - \code{\link{omxBrownie}}
#' @references - [The Food Lab](https://www.amazon.co.uk/Food-Lab-Cooking-Through-Science/dp/0393081087)
#' @examples
#' umxBrownie()
#' @md
umxBrownie <- function() {
	message("Rub steak in a table spoon of salt, put it back in the fridge for an hour (longer is fine).\n",
	"Place steak on a hot cast-iron skillet, with a little peanut oil.\n",
	"Turn steaks as often as you wish. Control heat to below smoke point.\n",
	"Remove and eat when internal temp reaches 130 \u0080 F.\n"
	)
}

# ==============================
# = Get and set OpenMx options =
# ==============================
#' umx_get_options
#'
#' Show the umx options. Useful for beginners to discover, or people like me to remember :-)
#'
#' @return - message
#' @export
#' @family Get and set
#' @examples
#' umx_get_options()
umx_get_options <- function() {
	umx_set_auto_plot()
	umx_set_plot_format()
	umx_set_plot_file_suffix()
	umx_set_table_format()
	umx_set_optimizer()
	message(umx_set_cores(silent = TRUE), " cores will be used")
	umx_set_auto_run() 
	umx_set_condensed_slots()
}

#' Set output suffix used in umx plot (structural diagrams) files to disk 
#'
#' Set output file suffix (default = "gv", alternative is "dot"). If you call this with no
#' value, it will return the current setting. If you call it with TRUE, it toggles the setting.
#'
#' @param umx.plot.suffix the suffix for plots files (if empty, returns the current value of umx.plot.format). If "TRUE", then toggles
#' @param silent If TRUE, no message will be printed.
#' @return - Current umx.plot.suffix setting
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' umx_set_plot_file_suffix() # print current state
#' old = umx_set_plot_file_suffix(silent = TRUE) # store current value
#' umx_set_plot_file_suffix("dot")
#' umx_set_plot_file_suffix("gv")
#' umx_set_plot_file_suffix(old) # reinstate
umx_set_plot_file_suffix <- function(umx.plot.suffix = NULL, silent = FALSE) {
	if(is.null(umx.plot.suffix)) {
		if(!silent){
			message("Current format is", 
				omxQuotes(getOption("umx.plot.suffix")),
				". Valid options are 'gv' or 'dot'. Use TRUE to toggle"
			)
		}
		invisible(getOption("umx.plot.suffix"))
	} else {
		if(umx.plot.suffix == TRUE){
			# if T then toggle
			if(getOption("umx.plot.suffix") == "gv"){
				umx.plot.suffix = "dot"
			} else {
				umx.plot.suffix = "gv"
			}
		} else {
			umx_check(umx.plot.suffix %in% c("gv", "dot"), "stop", "valid options are 'gv' or 'dot'. Use TRUE to toggle)")
		}
		options("umx.plot.suffix" = umx.plot.suffix)
	}
}

#' Set output format of plots (structural diagrams) in umx
#'
#' Set output format of plots (default = "DiagrammeR", alternative is "graphviz"). If you call this with no
#' value, it will return the current setting. If you call it with TRUE, it toggles the setting.
#'
#' @param umx.plot.format format for plots (if empty, returns the current value of umx.plot.format). If "TRUE", then toggles
#' @param silent If TRUE, no message will be printed.
#' @return - Current umx.plot.format setting
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' library(umx)
#' umx_set_plot_format() # print current state
#' old = umx_set_plot_format(silent = TRUE) # store current value
#' umx_set_plot_format("graphviz")
#' umx_set_plot_format("DiagrammeR")
#' umx_set_plot_format(old) # reinstate
umx_set_plot_format <- function(umx.plot.format = NULL, silent = FALSE) {
	if(is.null(umx.plot.format)) {
		if(!silent){
			message("Current format is", 
				omxQuotes(getOption("umx.plot.format")),
				". Valid options are 'graphviz' or 'DiagrammeR'. Use TRUE to toggle"
			)
		}
		invisible(getOption("umx.plot.format"))
	} else {
		if(umx.plot.format == TRUE){
			# if T then toggle
			if(getOption("umx.plot.format") == "graphviz"){
				umx.plot.format = "DiagrammeR"
			} else {
				umx.plot.format = "graphviz"
			}
		} else {
			umx_check(umx.plot.format %in% c("graphviz", "DiagrammeR"), "stop", "valid options are 'graphviz' or 'DiagrammeR'. Use TRUE to toggle)")
		}
		options("umx.plot.format" = umx.plot.format)
	}
}

#' umx_set_table_format
#'
#' Set knitr.table.format default (output style for tables). Legal values are 
#' "latex", "html", "markdown", "pandoc", and "rst".
#'
#' @param knitr.table.format format for tables (if empty, returns the current value of knitr.table.format)
#' @param silent If TRUE, no message will be printed.
#' @return - Current knitr.table.format setting
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' library(umx)
#' umx_set_table_format() # show current state
#' old = umx_set_table_format() # store existing value
#' umx_set_table_format("latex")
#' umx_set_table_format("html")
#' umx_set_table_format("markdown")
#' umx_set_table_format("") # get available options
#' umx_set_table_format(old)    # reinstate
umx_set_table_format <- function(knitr.table.format = NULL, silent = FALSE) {
	legal = c('latex', 'html', 'markdown', 'pandoc', 'rst')
	if(is.null(knitr.table.format)) {
		if(!silent){
			message("Current format is", omxQuotes(getOption("knitr.table.format")), 
				". Valid options are ", omxQuotes(legal)
			)
		}
		invisible(getOption("knitr.table.format"))		
	} else {
		if(!knitr.table.format %in% legal){
			message("legal options are ", omxQuotes(legal))
		} else {
			options("knitr.table.format" = knitr.table.format)
		}
	}
} # end umx_set_table_format


#' umx_set_auto_plot
#'
#' Set autoPlot default for models like umxACE umxGxE etc.
#'
#' @param autoPlot If TRUE, sets the umx_auto_plot option. Else returns the current value of umx_auto_plot
#' @param silent If TRUE, no message will be printed.
#' @return - Current umx_auto_plot setting
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' library(umx)
#' umx_set_auto_plot() # print current state
#' old = umx_set_auto_plot(silent = TRUE) # store existing value
#' umx_set_auto_plot(TRUE)   # set to on (internally stored as "name")
#' umx_set_auto_plot(FALSE)  # set to off (internally stored as NA)
#' umx_set_auto_plot(old)    # reinstate
umx_set_auto_plot <- function(autoPlot = NULL, silent = FALSE) {
	if(is.null(autoPlot)){
		if(!silent){
			message("Current plot format is ", omxQuotes(getOption("umx_auto_plot")),
				". 'name' means auto-plot is on (defaulting to the name of the model).", 
				" Use TRUE to turn on, FALSE to turn off."
			)
		}
		if(is.na(getOption("umx_auto_plot"))){
			autoPlot = FALSE
		} else {
			autoPlot = TRUE
		}
	}else{
		if(is.na(autoPlot) || autoPlot %in% FALSE){
			options("umx_auto_plot" = NA)		
			autoPlot = FALSE
		} else if(autoPlot == 'name' || autoPlot){
			options("umx_auto_plot" = "name")
			autoPlot = TRUE
		}
	}
	invisible(autoPlot)
}

#' umx_set_auto_run
#'
#' Set autoRun default for models like umxACE umxGxE etc.
#'
#' @param autoRun If TRUE or FALSE, sets the umx_auto_run option. Else returns the current value of umx_auto_run
#' @param silent If TRUE, no message will be printed.
#' @return - Current umx_auto_run setting
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' library(umx)
#' umx_set_auto_run() # print existing value
#' old = umx_set_auto_run(silent = TRUE) # store existing value
#' umx_set_auto_run(FALSE)  # set to FALSE
#' umx_set_auto_run(old)    # reinstate
umx_set_auto_run <- function(autoRun = NA, silent = FALSE) {
	if(is.na(autoRun)) {
		if(!silent){
			message(
				"Current auto-run setting is ", 
				omxQuotes(getOption("umx_auto_run")),
				". Valid options are TRUE or FALSE."
			)
		}
		invisible(getOption("umx_auto_run"))
	} else {
		umx_check(autoRun %in% c(TRUE, FALSE), "stop")
		options("umx_auto_run" = autoRun)
	}
}

#' umx_set_condensed_slots
#'
#' Sets whether newly-created mxMatrices are to be condensed (set to NULL if not being used) or not.
#'
#' @param state what state (TRUE or FALSE) to set condensed slots (default NA returns current value).
#' @param silent If TRUE, no message will be printed.
#' @return - current value of condensed slots
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' library(umx)
#' umx_set_condensed_slots() # print
#' old = umx_set_condensed_slots(silent = TRUE) # store the existing state
#' umx_set_condensed_slots(TRUE) # update globally
#' umx_set_condensed_slots(old) # set back
umx_set_condensed_slots <- function(state = NA, silent = FALSE) {
	if(is.na(state)){
		if(!silent){
			message("mxCondenseMatrixSlots is currently: ",
				omxQuotes(getOption('mxCondenseMatrixSlots'))
			)
		}
		invisible(getOption('mxCondenseMatrixSlots'))
	} else {
		if(!is.logical(state)){
			stop("mxCondenseMatrixSlots must be TRUE or FALSE you tried ", omxQuotes(state))
		}else{
			options(mxCondenseMatrixSlots = state)			
		}
	}
}



#' umx_set_optimization_options
#'
#' Set options that affect optimization in OpenMx. For mvnRelEps,  values between .0001 to .01 are conventional.
#' Smaller values slow optimization.
#'
#' @param opt default returns current values of the options listed. Currently
#' "mvnRelEps" and "mvnMaxPointsA".
#' @param value If not NULL, the value to set the opt to (can be a list of length(opt))
#' @param silent If TRUE, no message will be printed.
#' @param model A model for which to set the optimizer. Default (NULL) sets the optimizer globally.
#' @return - 
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' umx_set_optimization_options() # print the existing state(s)
#' umx_set_optimization_options("mvnRelEps") # show this one
#' \dontrun{
#' umx_set_optimization_options("mvnRelEps", .01) # update globally
#' }
umx_set_optimization_options <- function(opt = c("mvnRelEps", "mvnMaxPointsA"), value = NULL, model = NULL, silent = FALSE) {
	if(is.null(value)){
		# print current values for each item in opt
		for (this in opt) {			
			if(is.null(model)){
				o = mxOption(NULL, this)
			} else {
				o = mxOption(model, this)
			}
			message(paste0("Current ", this , " is: ", omxQuotes(o)))
		}
		invisible(o)
	} else {
		# Set options
		if(length(opt)!=length(value)){
			stop("For safe coding, please match opt and value lengths")
		} else {
			i = 1
			for (this in opt) {
				if(is.null(model)){
					o = mxOption(NULL, this, value[i])
				} else {
					o = mxOption(model, this, value[i])
				}
			}
		}
	}
}

#' umx_set_optimizer
#'
#' Set the optimizer in OpenMx
#'
#' @param opt default (NA) returns current value. Current alternatives are
#' "NPSOL" "SLSQP" and "CSOLNP".
#' @param model A model for which to set the optimizer. Default (NULL) sets the optimizer globally.
#' @param silent If TRUE, no message will be printed.
#' @return - 
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' library(umx)
#' umx_set_optimizer() # print the existing state
#' old = umx_set_optimizer(silent = TRUE) # store the existing state
#' umx_set_optimizer("SLSQP") # update globally
#' umx_set_optimizer(old) # set back
umx_set_optimizer <- function(opt = NA, model = NULL, silent = FALSE) {
	if(is.na(opt)){
		if(is.null(model)){
			o = mxOption(NULL, "Default optimizer")
		} else {
			o = mxOption(model, "Default optimizer")
		}
		if(!silent){
			quoteOptions = omxQuotes(mxAvailableOptimizers())
			message("Current Optimizer is: ", omxQuotes(o), ". Options are: ", quoteOptions)
		}
		invisible(o)
	} else {
		if(!opt %in% mxAvailableOptimizers()){
			stop("The Optimizer ", omxQuotes(opt), " is not legal. Legal values (from mxAvailableOptimizers() ) are:",
			omxQuotes(mxAvailableOptimizers()))
		}
		if(is.null(model)){
			mxOption(NULL, "Default optimizer", opt)	
		} else {
			stop(paste0("'Default optimizer' is a global option and cannot be set on models. just say:\n",
			"umx_set_optimizer(", omxQuotes(opt), ")"))
		}
	}
}

#' umx_set_cores
#'
#' set the number of cores (threads) used by OpenMx
#'
#' @param cores number of cores to use. NA (the default) returns current value. "-1" will set to detectCores().
#' @param model an (optional) model to set. If left NULL, the global option is updated.
#' @param silent If TRUE, no message will be printed.
#' @return - number of cores
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' library(umx)
#' manifests = c("mpg", "disp", "gear")
#' m1 <- mxModel("ind", type = "RAM",
#' 	manifestVars = manifests,
#' 	mxPath(from = manifests, arrows = 2),
#' 	mxPath(from = "one", to = manifests),
#' 	mxData(mtcars[, manifests], type = "raw")
#' )
#' umx_set_cores() # print current value
#' oldCores <- umx_set_cores(silent = TRUE)  # store existing value
#' umx_set_cores(parallel::detectCores()) # set to max
#' umx_set_cores(-1); umx_set_cores() # set to max
#' m1 = umx_set_cores(1, m1)  # set m1 useage to 1 core
#' umx_set_cores(model = m1)  # show new value for m1
#' umx_set_cores(oldCores)    # reinstate old global value
umx_set_cores <- function(cores = NA, model = NULL, silent = FALSE) {
	# depends on parallel::detectCores
	if(is.na(cores)){
		n = mxOption(model, "Number of Threads") # get the old value
		if(!silent){
			message(n, "/", parallel::detectCores() )
		}
		return(n)
	} else if(umx_is_MxModel(cores)) {
		stop("Call this as umx_set_cores(cores, model), not the other way around")
	}else{
		if(!is.numeric(cores)){
			stop("cores must be a number. You gave me ", cores)
		}
		umx_check(isTRUE(all.equal(cores, as.integer(cores))), message = paste0("cores must be an integer. You gave me: ", cores))
		if(cores > detectCores() ){
			message("cores set to maximum available (request (", cores, ") exceeds number possible: ", detectCores() )
			cores = detectCores()
		} else if (cores < 1){
			cores = detectCores()
		}
		mxOption(model, "Number of Threads", cores)		
	}
}

#' umx_set_checkpoint
#'
#' Set the checkpoint status for a model or global options
#'
#' @aliases umx_set_checkpoint umx_checkpoint
#' @param interval How many units between checkpoints: Default =  1.
#' A value of zero sets always to 'No' (i.e., do not checkpoint all models during optimization)
#' @param units units to count in: Default unit is 'evaluations' ('minutes' is also legal)
#' @param prefix string prefix to add to all checkpoint filenames (default = "")
#' @param directory a directory, i.e "~/Desktop" (defaults to getwd())
#' @param model (optional) model to set options in (default = NULL)
#' @return - mxModel if provided
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}, \url{https://openmx.ssri.psu.edu}
#' @examples
#' umx_set_checkpoint(interval = 1, "evaluations", dir = "~/Desktop/")
#' # turn off checkpointing with interval = 0
#' umx_set_checkpoint(interval = 0)
#' umx_set_checkpoint(2, "evaluations", prefix="SNP_1")
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1.0)
#' )
#' m1 = umx_set_checkpoint(model = m1)
#' m1 = mxRun(m1)
#' umx_checkpoint(0)
umx_set_checkpoint <- function(interval = 1, units = c("evaluations", "iterations", "minutes"), prefix = "", directory = getwd(), model = NULL) {
	if(umx_is_MxModel(interval)){
		stop("You passed in a model as the first parameter. You probably want:\n",
		"umx_is_MxModel(model=yourModel)")
	}
	units = match.arg(units)
	if(interval == 0){
		always = "No"
	} else {
		always = "Yes"
	}
	if(is.null(model)){
		# Whether to checkpoint all models during optimization.
		mxOption(NULL, "Always Checkpoint"   , always)

		# The number of units between checkpoint intervals
		mxOption(NULL, "Checkpoint Count"    , interval)

		# The type of units for checkpointing: 'minutes', 'iterations', or 'evaluations'.
		mxOption(NULL, "Checkpoint Units"    , units)	

		# The string prefix to add to all checkpoint filenames.
		mxOption(NULL, "Checkpoint Prefix"   , prefix)

		# the directory into which checkpoint files are written.
		mxOption(NULL, "Checkpoint Directory", directory)
	} else {
		model = mxOption(model, "Always Checkpoint"   , always)
		model = mxOption(model, "Checkpoint Count"    , interval)
		model = mxOption(model, "Checkpoint Units"    , units)
		model = mxOption(model, "Checkpoint Prefix"   , prefix)
		model = mxOption(model, "Checkpoint Directory", directory)
		return(model)
	}
}

#' @export
umx_checkpoint <- umx_set_checkpoint

#' umx_get_checkpoint
#'
#' get the checkpoint status for a model or global options
#'
#' @param model an optional model to get options from
#' @return - NULL
#' @export
#' @family Get and set
#' @references - \url{https://tbates.github.io}
#' @examples
#' umx_get_checkpoint() # current global default
#' require(umx)
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' m1 = umx_set_checkpoint(interval = 2, model = m1)
#' umx_get_checkpoint(model = m1)
umx_get_checkpoint <- function(model = NULL) {
	message("Always Checkpoint: "    , mxOption(model, "Always Checkpoint") )
	message("Checkpoint  Count: "    , mxOption(model, "Checkpoint Count" ) )
	message("Checkpoint  Units: "    , mxOption(model, "Checkpoint Units" ) )
	message("Checkpoint  Prefix: "   , mxOption(model, "Checkpoint Prefix" ) )	
	message("Checkpoint  Directory: ", mxOption(model, "Checkpoint Directory" ) )
}

#' Check if OpenMx is using OpenMP, test cores, and get timings
#'
#' Shows how many cores you are using, and runs a test script so user can check CPU usage.
#'
#' @details
#' Some historical (starting 2017-09-06) speeds on my late 2015 iMac, 3.3 GHz Quad-core i7 desktop.
#' 
#' R: 3.4.1 (2017-06-30); MacOS: 10.13
#' 
#' umx: 1.9.0; OpenMx: 2.7.16.26 [GIT v2.7.16-26-gd46131ce-dirty] / 2.7.16.31
#' 
#' \tabular{rllll}{
#'	date       \tab type            \tab x core  \tab 01 min, XX.XX sec \tab                                 \cr                  
#'	2022-12-31 \tab v3.0.0.future   \tab x core  \tab 00 min, 0.30 sec  \tab                                 \cr
#'	2018-09-17 \tab v2.11.3         \tab 1 core  \tab 01 min, 31 sec    \tab                                 \cr
#'	2018-09-17 \tab v2.11.3         \tab 4 core  \tab 00 min, 30.6 sec  \tab \eqn{\Delta}{&Delta;}: -61.49) \cr
#'	2017-10-16 \tab v2.7.18-9       \tab x core  \tab 01 min, 07.30 sec \tab                                 \cr                  
#'	2017-10-16 \tab v2.7.18-9       \tab y core  \tab 00 min, 22.63 sec \tab \eqn{\Delta}{&Delta;}: -44.68) \cr
#'	2017-10-16 \tab Clang OpenMP    \tab 1 core  \tab 01 min, 08.38 sec \tab                                 \cr                  
#'	2017-10-16 \tab Clang OpenMP    \tab 4 core  \tab 00 min, 24.89 sec \tab \eqn{\Delta}{&Delta;}: -43.49) \cr
#'	2017-09-07 \tab Clang OpenMP    \tab 1 core  \tab 01 min, 12.90 sec \tab                                 \cr
#'	2017-09-07 \tab Clang OpenMP    \tab 4 core  \tab 00 min, 32.20 sec \tab \eqn{\Delta}{&Delta;}: -40.70   \cr
#'	2017-09-07 \tab Clang notOpenMP \tab 1 core  \tab 01 min, 09.90 sec \tab                                 \cr
#'	2017-09-07 \tab TRAVIS          \tab 1 core  \tab 01 min, 06.20 sec \tab                                 \cr
#'	2017-09-07 \tab TRAVIS          \tab 4 core  \tab 00 min, 21.10 sec \tab \eqn{\Delta}{&Delta;}: -45.00   \cr
#' }
#' 
#' @param nCores How many cores to run (defaults to c(1, max/2). -1 = all available.
#' @param testScript A user-provided script to run (NULL)
#' @param rowwiseParallel Whether to parallel-ize rows (default) or gradient computation 
#' @param nSubjects Number of rows to model (Default = 1000) Reduce for quicker runs.
#' @return - NULL
#' @export
#' @family Test
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' \dontrun{
#' # On a fast machine, takes a minute with 1 core
#' umx_check_parallel()
#' }
umx_check_parallel <- function(nCores = c(1, parallel::detectCores()/2), testScript = NULL, rowwiseParallel = TRUE, nSubjects = 1000) {
	if(!is.null(testScript)){
		stop("test script not implemented yet - beat on tim to do it!")
	}
	oldCores = umx_set_cores()
	if( (length(nCores) == 1) && (nCores == -1)){
		nCores = detectCores()
	}
	message("You have been using ", oldCores, " of ", parallel::detectCores(), " available cores (0 means max - 1)")
	message("I will now set cores to ", omxQuotes(nCores), " (they will be reset after) and run a script that hits that many cores if possible.\n",
	"Check CPU while it's running and see if R is pegging the processor.")
	set.seed(10)
	# nSubjects = 1000
	numberIndicators = 12
	numberFactors    = 3
	fixedBMatrixF    = matrix(c(.4, .2), 2, 1, byrow = TRUE)
	randomBMatrixF   = matrix(c(.3, .5), 2, 1, byrow = TRUE)
	XMatrixF         = matrix(rnorm(nSubjects * 2, mean = 0, sd = 1), nSubjects, 2)
	UMatrixF         = matrix(rnorm(nSubjects * 1, mean = 0, sd = 1), nSubjects, 1)
	Z = matrix(rnorm(nSubjects, mean = 0, sd = 1), nrow=nSubjects, ncol = 2)

	XMatrix = cbind(XMatrixF, XMatrixF %*% fixedBMatrixF + (XMatrixF*Z) %*% randomBMatrixF + UMatrixF)

	BMatrix = matrix(c( 1, .6, .7, .8,  0,  0,  0,  0,  0,  0,  0,  0,
	                     0,  0,  0,  0,  1, .5, .6, .7,  0,  0,  0,  0,
	                     0,  0,  0,  0,  0,  0,  0,  0,  1, .7, .6, .5), numberFactors, numberIndicators, byrow=TRUE)
	UMatrix = matrix(rnorm(nSubjects*numberIndicators, mean=0, sd=1), nSubjects, numberIndicators)
	YMatrix = XMatrix %*% BMatrix + UMatrix
	dimnames(YMatrix) = list(NULL, paste("X", 1:numberIndicators, sep=""))

	latentMultiRegModerated1 = cbind(YMatrix,Z=Z[,1])
	latentMultiRegModerated1[,'Z'] = latentMultiRegModerated1[,'Z'] - mean(latentMultiRegModerated1[,'Z'])
	numberFactors    = 3
	numberIndicators = 12
	numberModerators = 1
	indicators       = paste("X", 1:numberIndicators, sep="")
	moderators       = c("Z")
	totalVars        = numberIndicators + numberFactors + numberModerators

	# Build orthogonal simple structure factor model

	latents        = paste0("F", 1:numberFactors)
	latents1       = latents[1]
	indicators1    = indicators[1:4]
	latents2       = latents[2]
	indicators2    = indicators[5:8]
	latents3       = latents[3]
	indicators3    = indicators[9:12]

	# Create model with both direct and moderated paths
	test1 <- mxModel("threeLatentWithModerator", type = "RAM",
	  manifestVars = c(indicators),
	  latentVars   = c(latents, "dummy1"),
	  umxPath(latents1 , to = indicators1, connect = "all.pairs", values = .2),
		umxPath(latents2 , to = indicators2, connect = "all.pairs", values = .2),
		umxPath(latents3 , to = indicators3, connect = "all.pairs", values = .2),
		umxPath(latents1, to = indicators1[1], fixedAt = 1),
		umxPath(latents2, to = indicators2[1], fixedAt = 1),
		umxPath(latents3, to = indicators3[1], fixedAt = 1),
		umxPath(var = latents   , values = .8),
		umxPath(var = indicators, values = .8),
		umxPath(c("F1", "F2"), to = "F3", values = .2, labels = c("b11", "b12")),
		umxPath("F1",to = "F2", values = .1, labels = "cF1F2"),
		umxPath(c("F1", "F2"),to = "dummy1", values = .2, labels = c("b21", "b22")),
		umxPath("dummy1",to = "F3", free = FALSE, labels = "data.Z"),
		umxPath(means = indicators, fixedAt = 0),
		umxPath(means = latents, values = .1),
		mxData(latentMultiRegModerated1, type = "raw")
	)
	
	# set rowwiseParallel
	if(packageVersion("OpenMx") >= "2.6.1"){
		# test1$fitfunction$rowwiseParallel = rowwiseParallel
	} else {
		message("ignored rowwiseParallel: upgrade to OpenMx 2.6.1 or better to use this")
		# ignore: this is not supported by versions before 2.6.1
	}
	# nCores = 4
	n = 1
	for (thisCores in nCores) {
		if(n == 1){
			models = list(test1) # initialize
		} else {
			models = append(models, test1)
		}
		n = n + 1
	}
	n = 1
	# run each model
	# thisCores = 4
	for (thisCores in nCores) {
		umx_set_cores(thisCores)
		thisModel = mxRename(models[[n]], paste0("nCcores_equals_", thisCores))
		thisModel = mxRun(thisModel)
		# umx_time(thisModel, autoRun= F)
		models[[n]] = thisModel
		n = n + 1
	}
	umx_set_cores(oldCores)
	# umx_time(models, autoRun= F)
	invisible(umx_time(models, formatStr = "%M %OS3", autoRun = FALSE))
}

# ======================================
# = Lower-level Model building helpers =
# ======================================

#' umxJiggle
#'
#' umxJiggle takes values in a matrix and jiggles them
#'
#' @param matrixIn an \code{\link{mxMatrix}} to jiggle the values of
#' @param mean the mean value to add to each value
#' @param sd the sd of the jiggle noise
#' @param dontTouch A value, which, if found, will be left as-is (defaults to 0)
#' @return - \code{\link{mxMatrix}}
#' @family Advanced Model Building Functions
#' @references - \url{https://www.github.com/tbates/umx}
#' @export
#' @examples
#' \dontrun{
#' mat1 = umxJiggle(mat1)
#' }
umxJiggle <- function(matrixIn, mean = 0, sd = .1, dontTouch = 0) {
	mask = (matrixIn != dontTouch);
	newValues = mask;
	matrixIn[mask == TRUE] = matrixIn[mask == TRUE] + rnorm(length(mask[mask == TRUE]), mean = mean, sd = sd);
	return (matrixIn);
}


# ===============
# = RAM helpers =
# ===============
#' umx_is_exogenous
#'
#' Return a list of all the exogenous variables (variables with no incoming single-arrow path) in a model. 
#'
#' @param model an \code{\link{mxModel}} from which to get exogenous variables
#' @param manifests_only Whether to check only manifests (default = TRUE)
#' @return - list of exogenous variables
#' @export
#' @family Test
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}, \url{https://openmx.ssri.psu.edu}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath("g", to = names(demoOneFactor)),
#' 	umxPath(var = "g", fixedAt = 1),
#' 	umxPath(var = names(demoOneFactor))
#' )
#' umx_is_exogenous(m1, manifests_only = TRUE)
#' umx_is_exogenous(m1, manifests_only = FALSE)
umx_is_exogenous <- function(model, manifests_only = TRUE) {
	umx_check_model(model, type = "RAM")
	checkThese = model@manifestVars
	if(!manifests_only){
		checkThese = c(checkThese, model@latentVars)
	}
	if(length(checkThese) < 1){
		return(c())
	}
	exog = c()
	n = 1
	for (i in checkThese) {
		if(!any(model$matrices$A$free[i, ])){
			exog[n] = i
			n = n + 1
		}
	}
	return(exog)
}

#' umx_is_endogenous
#'
#' Return a list of all the endogenous variables (variables with at least one incoming single-arrow path) in a model.
#'
#' @param model an \code{\link{mxModel}} from which to get endogenous variables
#' @param manifests_only Whether to check only manifests (default = TRUE)
#' @return - list of endogenous variables
#' @export
#' @family Test
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}, \url{https://openmx.ssri.psu.edu}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' m1 <- umxRAM("One Factor", data = mxData(cov(demoOneFactor), type = "cov", numObs = 500),
#' 	umxPath("g", to = names(demoOneFactor)),
#' 	umxPath(var = "g", fixedAt = 1),
#' 	umxPath(var = names(demoOneFactor))
#' )
#' umx_is_endogenous(m1, manifests_only = TRUE)
#' umx_is_endogenous(m1, manifests_only = FALSE)
umx_is_endogenous <- function(model, manifests_only = TRUE) {
	# has_no_incoming_single_arrow
	umx_check_model(model, type = "RAM")
	checkThese = model@manifestVars
	if(!manifests_only){
		checkThese = c(checkThese, model@latentVars)
	}
	if(length(checkThese) < 1){
		return(c())
	}
	endog = c()
	n = 1
	for (i in checkThese) {
		# any free paths in this row?
		if(any(model$matrices$A$free[i, ])){
			endog[n] = i
			n = n + 1
		}
	}
	return(endog)
}

#' umx_add_variances
#'
#' Convenience function to save the user specifying mxPaths adding variance to each variable
#'
#' @param model an \code{\link{mxModel}} to add variances to
#' @param add.to = List of variables to create variance for
#' @param free = List of variables to create variance for (default = NULL)
#' @param values = List of values (default = NULL)
#' @return - \code{\link{mxModel}}
#' @export
#' @family Advanced Model Building Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}, \url{https://openmx.ssri.psu.edu}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' m1 <- mxModel("One Factor", type = "RAM",
#'  manifestVars = names(demoOneFactor),
#'  latentVars = "g",
#' 	mxPath(from = "g", to = names(demoOneFactor), values= .1),
#' 	mxData(cov(demoOneFactor), type = "cov", numObs = 500)
#' )
#' umx_show(m1, matrices = "S") # variables lack variance :-(
#' m1 = umx_add_variances(m1, add.to = names(demoOneFactor))
#' m1 = umx_add_variances(m1, add.to = "g", FALSE, 1)
#' umx_show(m1, matrices = "S") 
#' # Note: latent g has been treated like the manifests...
#' # umxFixLatents() will take care of this for you...
#' m1 = umxRun(m1, setLabels = TRUE, setValues = TRUE)
#' umxSummary(m1)
umx_add_variances <- function(model, add.to, values = NULL, free = NULL) {
	umx_check_model(model, type = "RAM")
	theList = c(model@latentVars, model@manifestVars)
	if(!all(add.to %in% theList)){
		stop("not all names found in model")
	}
	for (i in add.to) {
		model$S@free[i, i] = TRUE
		model$S@values[i, i] = .1
	}
	return(model)
}

#' umx_fix_latents
#'
#' Fix the variance of all, or selected, exogenous latents at selected values. This function adds a variance to the factor if it does not exist.
#'
#' @param model an \code{\link{mxModel}} to set
#' @param latents (If NULL then all latentVars)
#' @param exogenous.only only touch exogenous latents (default = TRUE)
#' @param at (Default = 1)
#' @return - \code{\link{mxModel}}
#' @export
#' @family Advanced Model Building Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}, \url{https://openmx.ssri.psu.edu}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' m1 <- mxModel("One Factor", type = "RAM",
#'  manifestVars = names(demoOneFactor),
#'  latentVars = "g",
#' 	mxPath(from = "g", to = names(demoOneFactor)),
#' 	mxPath(from = names(demoOneFactor), arrows = 2),
#' 	mxData(cov(demoOneFactor), type = "cov", numObs = 500)
#' )
#' umx_show(m1, matrices = "S") # variance of g is not set
#' m1 = umx_fix_latents(m1)
#' umx_show(m1, matrices = "S") # variance of g is fixed at 1
umx_fix_latents <- function(model, latents = NULL, exogenous.only = TRUE, at = 1) {
	if(is.null(latents)){
		latenVarList = model@latentVars
	} else {
		latenVarList = latents
	}
	exogenous_list = umx_is_exogenous(model, manifests_only = FALSE)
	for (i in latenVarList) {
		if(!exogenous.only | i %in% exogenous_list){
			model$S@free[i, i]   = FALSE
			model$S@values[i, i] = at
		}
	}
	return(model)
}

#' umx_fix_first_loadings
#'
#' Fix the loading of the first path from each latent at selected value. 
#' Note: latents with fixed variance are skipped.
#' @param model An \code{\link{mxModel}} to set.
#' @param latents Which latents to fix from (NULL = all).
#' @param at The value to fix the first path at (Default = 1).
#' @return - \code{\link{mxModel}}
#' @export
#' @family Advanced Model Building Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}, \url{https://openmx.ssri.psu.edu}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' m1 <- mxModel("One Factor", type = "RAM",
#'  manifestVars = names(demoOneFactor),
#'  latentVars = "g",
#' 	mxPath(from = "g", to = names(demoOneFactor)),
#' 	mxPath(from = names(demoOneFactor), arrows = 2),
#' 	mxData(cov(demoOneFactor), type = "cov", numObs = 500)
#' )
#' m1 = umx_fix_first_loadings(m1)
#' umx_show(m1) # path from g to var1 fixed @ 1.
umx_fix_first_loadings <- function(model, latents = NULL, at = 1) {
	umx_check_model(model, type = "RAM")
	if(is.null(latents)){
		latentVarList = model@latentVars
	} else {
		latentVarList = latents
	}
	if(length(latentVarList)==0){
		stop("You appear to have no latents in this model...")
	}

	for (thisLatent in latentVarList) {
		# thisLatent = "ind60"
		if(!model$A$free[thisLatent, thisLatent]){
			# "this latent is fixed... don't scale first loading"
		} else {
			firstFreeRow = which(model$A$free[, thisLatent])[1]
			# check that there is not already a factor fixed prior to this one
			if(firstFreeRow == 1){
				# must be ok
				model$A@free[firstFreeRow, thisLatent]   = FALSE
				model$A@values[firstFreeRow, thisLatent] = at
			} else {
				if(any(model$matrices$A$values[1:(firstFreeRow-1), thisLatent] == at)){
					message("I skipped factor '", thisLatent, "'. It looks like it already has a loading fixed at ", at)
				} else {
					model$A@free[firstFreeRow, thisLatent]   = FALSE
					model$A@values[firstFreeRow, thisLatent] = at				
				}
			}
		}
	}
	return(model)
}

#' umx_drop_ok
#'
#' Print a meaningful sentence about a model comparison. If you use this, please email me and ask to have it
#' merged with \code{\link{umxCompare}}() :-)
#'
#' @param model1 the base code{\link{mxModel}}
#' @param model2 the nested code{\link{mxModel}}
#' @param text name of the thing being tested, i.e., "Extraversion" or "variances"
#' @return - 
#' @export
#' @family Reporting functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(demoOneFactor)
#' latents   = c("g")
#' manifests = names(demoOneFactor)
#' myData    = mxData(cov(demoOneFactor), type = "cov", numObs = 500)
#' m1 <- umxRAM("OneFactor", data = myData,
#' 	umxPath(latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' m2 = umxModify(m1, update = "g_to_x1", name = "no effect on x1")
#' umx_drop_ok(m1, m2, text = "the path to x1")
umx_drop_ok <- function(model1, model2, text = "parameter") {
	a = mxCompare(model1, model2)
	if(a$diffdf[2] > 1){
		are = "are"
	}else{
		are = "is"
	}
	if(a$p[2] < .05){
		if(!is.null(text)){ print(paste0("The ", text, " ", are, " significant and should be kept (p = ", umx_APA_pval(a$p[2]), ")")) }
		return(FALSE)
	} else {
		if(!is.null(text)){ print(paste0("The ", text, " ", are, " non-significant and can be dropped (p = ", umx_APA_pval(a$p[2]), ")")) }
		return(TRUE)
	}
}

# ====================
# = Parallel Helpers =
# ====================

eddie_AddCIbyNumber <- function(model, labelRegex = "") {
	# eddie_AddCIbyNumber(model, labelRegex="[ace][1-9]")
	args     = commandArgs(trailingOnly=TRUE)
	CInumber = as.numeric(args[1]); # get the 1st argument from the cmdline arguments (this is called from a script)
	CIlist   = umxGetParameters(model ,regex= "[ace][0-9]", verbose= FALSE)
	thisCI   = CIlist[CInumber]
	model    = mxModel(model, mxCI(thisCI) )
	return (model)
}

#' Break twin variable names (BMI_T1, BMI_T2) into base variable names (BMI, "_T", 1:2)
#'
#' @description
#' Break names like Dep_T1 into a list of base names, a separator, and a 
#' vector of twin indexes. e.g.: c("Dep_T1", "Dep_T2", "Anx_T1", "Anx_T2") will become:
#' 
#' list(baseNames = c("Dep", "Anx"), sep = "_T", twinIndexes = c(1,2))
#'
#' @param df vector of names or data.frame containing the data
#' @param sep text constant separating name from numeric 1:2 twin index.
#' @return - list(baseNames, sep, twinIndexes)
#' @export
#' @family String Functions
#' @examples
#' require(umx)
#' data("twinData")
#' umx_explode_twin_names(twinData, sep = "")
#' umx_explode_twin_names(twinData, sep = NULL)
#' 
#' # Ignore this: just a single-character/single variable test case
#' x = round(10 * rnorm(1000, mean = -.2))
#' y = round(5 * rnorm(1000))
#' x[x < 0] = 0; y[y < 0] = 0
#' umx_explode_twin_names(data.frame(x_T1 = x, x_T2 = y), sep = "_T")
#' umx_explode_twin_names(data.frame(x_T11 = x, x_T22 = y), sep = "_T")
umx_explode_twin_names <- function(df, sep = "_T") {
	if(is.data.frame(df)){
		names_in_df = names(df)
	} else {
		names_in_df = df
	}
	regex3Parts = paste0("^(.+)", sep, "([0-9]+)$")
	legalVars   = grep(regex3Parts, names_in_df, value = TRUE)
	baseNames   = sub(regex3Parts, replacement = "\\1", x = legalVars)
	baseNames   = unique(baseNames)
	twinIndexes = sub(regex3Parts, replacement = "\\2", x = legalVars)
	twinIndexes = sort(unique(as.numeric(twinIndexes)))
	return(list(baseNames = baseNames, sep = sep, twinIndexes = twinIndexes))
}


# ===================================
# = Ordinal/Threshold Model Helpers =
# ===================================

#' umxFactor
#'
#' A convenient version of \code{\link{mxFactor}} supporting the common 
#' case in which the factor levels are those in the variable.
#'
#' @aliases umx_factor
#' @param x A variable to recode as an mxFactor (see \code{\link{mxFactor}})
#' @param levels (default NULL). Like \code{\link{factor}} but UNLIKE \code{\link{mxFactor}}, 
#' unique values will be used if levels not specified.
#' @param labels = levels (see \code{\link{mxFactor}})
#' @param exclude = NA (see \code{\link{mxFactor}})
#' @param ordered = TRUE By default return an ordered mxFactor
#' @param collapse = FALSE (see \code{\link{mxFactor}})
#' @param verbose Whether to tell user about such things as coercing to factor
#' @param sep If twin data are being used, the string that separates the base from twin index
#' # will try and ensure factor levels same across all twins.
#' @return - \code{\link{mxFactor}}
#' @export
#' @family Miscellaneous Utility Functions
#' @seealso - \code{\link{umxFactanal}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' umxFactor(letters)
#' umxFactor(letters, verbose = TRUE) # report coercions
#' umxFactor(letters, ordered = FALSE) # non-ordered factor like factor(x)
#' # Dataframe example:
#' x = umx_factor(mtcars[,c("cyl", "am")], ordered = FALSE); str(x)
#' # =================
#' # = Twin example: =
#' # =================
#' data(twinData)
#' tmp = twinData[, c("bmi1", "bmi2")]
#' tmp$bmi1[tmp$bmi1 <= 22] = 22
#' tmp$bmi2[tmp$bmi2 <= 22] = 22
#' # remember to factor _before_ breaking into MZ and DZ groups
#' x = umxFactor(tmp, sep = ""); str(x)
#' xmu_check_levels_identical(x, "bmi", sep="")
#' 
#' # Simple example to check behavior
#' x = round(10 * rnorm(1000, mean = -.2))
#' y = round(5 * rnorm(1000))
#' x[x < 0] = 0; y[y < 0] = 0
#' jnk = umxFactor(x); str(jnk)
#' df  = data.frame(x = x, y = y)
#' jnk = umxFactor(df); str(jnk)
umxFactor <- function(x = character(), levels= NULL, labels = levels, exclude = NA, ordered = TRUE, collapse = FALSE, verbose = FALSE, sep = NA){
	if(is.data.frame(x)){
		# x = tmp; sep = NA; sep = ""; thisName = "bmi"; levels = NA
		ncols = ncol(x)
		if(!is.na(sep)){
			if(!is.null(levels)){
				stop("leave levels = NA: I don't handle setting levels within data.frames AND sep. You set them to ", omxQuotes(levels))
			}
			tmp         = umx_explode_twin_names(x, sep = sep)
			sep         = tmp$sep
			baseNames   = tmp$baseNames
			twinIndexes = tmp$twinIndexes
			for (thisName in baseNames) {
				theseNames = umx_paste_names(thisName, sep, twinIndexes)
				a = x[, theseNames]
				allLevels = unique(as.vector(as.matrix(a)))
				allLevels = sort(allLevels)
				allLevels = allLevels[!is.na(allLevels)] # drop NA if present
				# z = umxFactor(x = x[,theseNames], levels = allLevels, ordered = T, verbose = T, collapse=FALSE)
				# z = umxFactor(x = x[,theseNames], levels = allLevels, labels = allLevels, ordered = T, verbose = T)
				x[, theseNames] = umxFactor(x = x[, theseNames, drop = FALSE], levels = allLevels, labels = allLevels, exclude = exclude, collapse = collapse, ordered = ordered, verbose = verbose)
			}
		} else {
			for (c in 1:ncols) {
				x[,c] = umxFactor(x = x[,c], levels = levels, labels = labels, exclude = exclude, collapse = collapse, ordered = ordered, verbose = verbose)
			}
		}
	} else {
		if(!is.factor(x)){
			if(!is.null(levels)) {
				x = factor(x, levels = levels, labels = labels, exclude = exclude, ordered = ordered)
			} else {
				x = factor(x, exclude = exclude, ordered = ordered)
			}
			levels = levels(x)
			if(verbose){
				if(length(levels) > 20){
					feedback = paste0(length(levels), " levels:", paste(c(levels[1:10], "..."), collapse = "', '"))
				} else {
					feedback = paste0("levels:", omxQuotes(levels))
				}
				message("Your variable was not a factor: I made it into one, with ", feedback)
			}
		}else{
			# Already a factor
			if(is.null(levels)) {
				levels = levels(x)
			} else {
				if(!levels(x) == levels){
					message("the levels you provided are not those I see in the data")
				}
			}
		}
		if(ordered){
			x = mxFactor(x = x, levels = levels, labels = levels, exclude = exclude, ordered = ordered, collapse = collapse)
		}
	}
	return(x)
}

#' @export
umx_factor <- umxFactor

# ===========
# = Utility =
# ===========

#' Get or print the version of umx, along with detail from OpenMx and general system info.
#'
#' @description
#' umxVersion returns the version information for umx, and for OpenMx and R.
#' Essential for bug-reports! This function can also test for a minimum version.
#'
#' @param model Optional to show optimizer in this model
#' @param min Optional minimum version string to test for, e.g. '2.7.0' (Default = NULL).
#' @param verbose = TRUE
#' @param return Which package (umx or OpenMx) to 'return' version info for (Default = umx).
#' @return - \code{\link{mxModel}}
#' @export
#' @family Miscellaneous Utility Functions
#' @seealso - \code{\link{packageVersion}}, \code{\link{install.OpenMx}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' x = umxVersion(); x
umxVersion <- function (model = NULL, min = NULL, verbose = TRUE, return = "umx") {
	umx_vers <- try(packageVersion("umx"))
    if (verbose) {
        msg = paste0("umx version: ", umx_vers)
        message(msg)
    }
	if(!is.null(min)){
		if(umx_vers >= min){
			message("umx version is recent enough")
		} else {
			stop("umx version is not recent enough to run this script! (min is ", min, "). You have ", umx_vers,
			"\n You can run umx_open_CRAN_page() to see the most recent version of umx on CRAN")
			
		}
	}
	OpenMx_vers = mxVersion(model = model, verbose = verbose)	
    if (verbose) {
		message('You can update OpenMx with:\ninstall.OpenMx(c("NPSOL", "travis", "CRAN", "open travis build page")')
    }

	if(return == "umx"){
		invisible(umx_vers)
	} else {
		invisible(OpenMx_vers)
	}
}

#' Open the CRAN page for a package
#' 
#' On MacOS, this function opens the CRAN page for a package.
#' Useful for looking up documentation, checking you have an
#' up-to-date version, showing the package to people etc.
#' @param package An \R package name.
#' @return - 
#' @export
#' @family Miscellaneous Utility Functions
#' @examples
#' \dontrun{
#' umx_open_CRAN_page("umx")
#' }
umx_open_CRAN_page <- function(package = "umx") {
	for (p in package) {
		result = tryCatch({
		    print(packageVersion(p))
		}, warning = function(x) {
		    print("not installed locally")
		}, error = function(x) {
		    print("not installed locally")
		}, finally={
		    # print("cleanup-code")
		})		
		system(paste0("open 'https://cran.r-project.org/package=", p, "'"))		
	}
}

#' Pad an Object with NAs
#' 
#' This function pads an R object (list, data.frame, matrix, atomic vector)
#' with \code{NA}s. For matrices, lists and data.frames, this occurs by extending
#' each (column) vector in the object.
#' @param x An \R object (list, data.frame, matrix, atomic vector).
#' @param n The final length of each object.
#' @return - padded object
#' @export
#' @family Miscellaneous Utility Functions
#' @references - \url{https://github.com/kevinushey/Kmisc/tree/master/man}
#' @examples
#' umx_pad(1:3, 4)
#' umx_pad(1:3, 3)
umx_pad <- function(x, n) {
  if (is.data.frame(x)) {
    nrow <- nrow(x)
    attr(x, "row.names") <- 1:n
    for( i in 1:ncol(x) ) {
      x[[i]] <- c( x[[i]], rep(NA, times = n - nrow) )
    }
    return(x)
  } else if (is.list(x)) {
    if (missing(n)) {
      max_len <- max( sapply( x, length ) )
      return( lapply(x, function(xx) {
        return( c(xx, rep(NA, times=max_len-length(xx))) )
      }))
    } else {
      return( lapply(x, function(xx) {
        if (n > length(xx)) {
          return( c(xx, rep(NA, times=n-length(xx))) )
        } else {
          return(xx)
        }
      }))
    }
  } else if (is.matrix(x)) {
    return( rbind( x, matrix(NA, nrow=n-nrow(x), ncol=ncol(x)) ) )
  } else {
    if (n > length(x)) {
			return( c( x, rep(NA, n-length(x)) ) ) 
    } else {
      return(x)
    }
  } 
}

#' umx_apply
#'
#' Tries to make apply more readable. so "mean of x by columns", instead of "of x, by 2, mean"
#' Other functions to think of include:
#' \code{\link{cumsum}}, \code{\link{rowSums}}, \code{\link{colMeans}}, etc.
#'
#' @param FUN The function to apply.
#' @param of The dataframe to work with.
#' @param by Apply the function to columns or to rows (default = "columns")
#' @param ... optional arguments to FUN, e.g., na.rm = TRUE.
#' @return - object
#' @export
#' @seealso - \code{\link{umx_aggregate}} 
#' @family Miscellaneous Stats Helpers
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' umx_apply(mean, mtcars, by = "columns")
#' umx_apply(mean, of = mtcars, by = "columns")
#' umx_apply(mean, by = "rows", of = mtcars[1:3,], na.rm = TRUE)
umx_apply <- function(FUN, of, by = c("columns", "rows"), ...) {
	by = match.arg(by)
	if (by == "rows") {
		by = 1
	} else {
		by = 2		
	}
	apply(of, by, FUN, ...)
}

#' umx_as_numeric
#' 
#' Convert each column of a dataframe to numeric
#'
#' @param df A \code{\link{data.frame}} to convert
#' @param force Whether to force conversion to numeric for non-numeric columns (defaults to FALSE)
#' @return - data.frame
#' @family Data Functions
#' @export
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' df = mtcars
#' # make mpg into string
#' df$mpg = as.character(df$mpg)
#' df$cyl = factor(df$cyl)
#' df = umx_as_numeric(df); str(df)
#' df = umx_as_numeric(df, force=TRUE); str(df)
#' # Make one variable alpha
#' df$mpg = c(letters,letters[1:6]); str(df)
#' df = umx_as_numeric(df, force=TRUE); str(df)
umx_as_numeric <- function(df, force = FALSE) {
	# TODO umx_as_numeric: Handle matrices, vectors...
	colsToConvert = names(df)
	if(!force){
		# just the numeric names
		colsToConvert = colsToConvert[umx_is_numeric(df)]
	}
	for (i in colsToConvert) {
		df[ ,i] = as.numeric(df[ ,i])
	}
	return(df)
}

#' umx_find_object
#'
#' Find objects a certain class, whose name matches a search string.
#' The string (pattern) is grep-enabled, so you can match wild-cards
#'
#' @param pattern the pattern that matching objects must contain
#' @param requiredClass the class of object that will be matched
#' @return - a list of objects matching the class and name
#' @export
#' @references - 
#' @family Miscellaneous Utility Functions
#' @examples
#' \dontrun{
#' umx_find_object("^m[0-9]") # mxModels beginning "m1" etc.
#' umx_find_object("", "MxModel") # all MxModels
#' }
umx_find_object <- function(pattern = ".*", requiredClass = "MxModel") {
	# Use case: umxFindObject("Chol*", "MxModel")
	matchingNames = ls(envir = sys.frame(-1), pattern = pattern) # envir
	matchingObjects = c()
	for (obj in matchingNames) {
		if(class(get(obj))[1] == requiredClass){
			matchingObjects = c(matchingObjects, obj)
		}
	}
	return(matchingObjects)
}

#' umx_rename
#'
#' Returns a dataframe with variables renamed as desired.
#' 
#' Unlike similar functions in other packages, it checks that the variables exist, and that the new names do not.
#' 
#' Importantly, it also supports [regular expressions][regex]. This allows you to find and replace
#' text based on patterns and replacements. so to change "replacement" to "inplace", 
#' `grep=re(place)ment`, `replace= in\\1`.
#'
#' *note*: to use replace list, you must say c(old = "new"), not c(old -> "new")
#' 
#' @param x the dataframe in which to rename variables
#' @param replace If used alone, a named collection of c(oldName = "newName") pairs
#'   OR, if "old" is a list of existing names, the list of new names)
#'   OR, if "grep" is a regular expression, the replace string)
#' @param old Optional list of old names that will be found and replaced by the contents of replace. Defaults to NULL.
#' @param grep Optional grep string. Matches will be replaced using replace as the replace string. Defaults to NULL.
#' @param test whether to report a "dry run" - and not actually change anything. Defaults to FALSE.
#' @return - dataframe with columns renamed.
#' @export
#' @seealso [namez] to filter (and replace) names, Also [umx_check_names] to check for existence of names in a dataframe.
#' @family Data Functions
#' @md
#' @examples
#' # Re-name "cyl" to "cylinder"
#' x = mtcars
#' x = umx_rename(x, replace = c(cyl = "cylinder"))
#' # alternate style
#' x = umx_rename(x, old = c("disp"), replace = c("displacement"))
#' umx_check_names("displacement", data = x, die = TRUE)
#' # This will warn that "disp" does not exist (anymore)
#' x = umx_rename(x, old = c("disp"), replace = c("displacement"))
#' x = umx_rename(x, grep = "lacement", replace = "") # using grep to revert to disp
#' umx_names(x, "^d") # all names begining with a d
umx_rename <- function(x, replace = NULL, old = NULL, grep = NULL, test = FALSE) {
	# See also gdate::rename.vars(data, from, to)	
	if(!is.null(old) && !is.null(grep)){
		stop("Only one of old and grep can be used")
	}
	if(!is.null(grep)){
		if(is.null(replace)){
			stop("Please set replace to a valid replacement string!")
		}
	    nameVector = umx_names(x)
	    if (is.null(nameVector)) {
	        stop(paste0("umx_rename requires a dataframe or something else with names(), ", 
	            umx_object_as_str(x), " is a ", typeof(x)))
	    }
		new_names = gsub(grep, replace, nameVector)
		if(test){
			message("The following changes would be made (set test =FALSE to actually make them)")
			message(length(nameVector), " names found. ",
			length(nameVector[!(nameVector == new_names)]), " changed. Old Was:")
			print(nameVector[!(nameVector == new_names)])
			message("New:")
			print(new_names[!(nameVector == new_names)])
		} else {
			if(class(x)=="character"){
				x = new_names
			} else {
				names(x) = new_names
			}
		}
		invisible(x)		
	} else {
		if(!is.null(old)){
		# message("replacing old with replace")
		if(length(old) != length(replace)){
			stop("You are trying to replace ", length(old), " old names with ", length(replace), "new names: Lengths must match")
		}
		names_to_replace <- old
		new_names_to_try <- replace
		} else {
			names_to_replace <- names(replace)
			new_names_to_try <- unname(replace)
		}
		old_names <- names(x)

		if(!all(names_to_replace %in% old_names)) {
			warning("The following names did not appear in the dataframe:", 
			paste(names_to_replace[!names_to_replace %in% old_names], collapse=", "), "\nperhaps you already updated them")
		}

		if(anyDuplicated(names_to_replace)) {
		  err <- paste("You are trying to update the following names more than once:", 
		           paste(names_to_replace[duplicated(names_to_replace)], collapse=", "))
		  stop(err)
		}

		if(anyDuplicated(new_names_to_try)) {
		  err <- paste("You have the following duplicates in your replace list:", 
		         	paste(new_names_to_try[duplicated(new_names_to_try)], collapse=", ")
		)
		  stop(err)
		}
		new_names <- new_names_to_try[match(old_names, names_to_replace)]  
		if(test){
			message("The following changes would be made (set test =FALSE to actually make them")
			message("Names to be replaced")
			print(names_to_replace)
			message("replacement names:")
			print(new_names)
			invisible(x)
		} else {
			names(x) = new_names
			setNames(x, ifelse(is.na(new_names), old_names, new_names)) # also returns the new object
		}
	}
}

#' umx_grep
#'
#' Search for text. Will search names if given a data.frame, or strings if given a vector of strings. 
#' NOTE: Handy feature is that this can search the labels of data imported from SPSS
#'
#' To simply grep for a pattern in a string just use R built-in grep* functions, e.g.:
#'  grepl("^NA\\[0-9]", "NA.3")
#' @param df The \code{\link{data.frame}} or string to search
#' @param grepString the search string
#' @param output the column name, the label, or both (default)
#' @param ignore.case whether to be case sensitive or not (default TRUE = ignore case)
#' @param useNames whether to search the names as well as the labels (for SPSS files with label metadata)
#' @return - list of matched column names and/or labels
#' @seealso - \code{\link{grep}} \code{\link{umx_names}} \code{\link{umx_aggregate}}
#' @family String Functions
#' @export
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' umx_grep(mtcars, "hp", output="both", ignore.case= TRUE)
#' umx_grep(c("hp", "ph"), "hp")
#' umx_grep(mtcars, "^h.*", output="both", ignore.case= TRUE)
#' \dontrun{
#' umx_grep(spss_df, "labeltext", output = "label") 
#' umx_grep(spss_df, "labeltext", output = "name") 
#' }
umx_grep <- function(df, grepString, output = c("both", "label", "name"), ignore.case=TRUE, useNames= FALSE) {
	output = match.arg(output)
	# if(length(grepString > 1)){
	# 	for (i in grepString) {
	# 		umx_grep_labels(df, i, output=output, ignore.case=ignore.case, useNames=useNames)
	# 	}
	if(is.data.frame(df)){
		vLabels = attr(df, "variable.labels") # list of descriptive labels?
		a       = names(df) 
		if(is.null(vLabels)){
			# message("No labels found")
			return(grep(grepString, names(df), value=TRUE, ignore.case= ignore.case))
		}
		if(useNames) {
			findIndex = grep(grepString,a, value=F, ignore.case=ignore.case)
			return( as.matrix(vLabels[findIndex]))
		} else {
			# need to cope with finding nothing
			findIndex = grep(grepString,vLabels, value=F, ignore.case=ignore.case)
			if(output=="both") {
				theResult <- as.matrix(vLabels[findIndex])
			} else if(output=="label"){
				vLabels= as.vector(vLabels[findIndex])
				theResult <- (vLabels)
			} else if(output=="name"){
				theResult <- names(vLabels)[findIndex]
			}else{
				stop(paste("bad choice of output:", output))
			}
			if(dim(theResult)[1]==0 |is.null(theResult)){
				cat("using names!!!!\n")
				findIndex = grep(grepString,a, value=F, ignore.case=ignore.case)
				return(as.matrix(vLabels[findIndex]))
			} else {
				return(theResult)
			}
		}
	} else {
		# TODO	umx_grep: Check input is string or vector of strings
		return(grep(grepString, df, value = TRUE, ignore.case = ignore.case))
	}
}

# ===========================
# = File handling functions =
# ===========================

#' umx_rename_file
#'
#' rename files. On OS X, the function can access the current front-most Finder window.
#' The file renaming is fast and, because you can use regular expressions, powerful
#'
#' @param findStr The (regex) string to find, i.e., "c[ao]t"
#' @param replaceStr The (regex) replacement string "\1 are not dogs"
#' @param baseFolder  The folder to search in. If set to "Finder" (and you are on OS X) it will use the current front-most Finder window. If it is blank, a choose folder dialog will be thrown.
#' @param listPattern A pre-filter for files
#' @param test Boolean determining whether to change files on disk, or just report on what would have happened (Defaults to test = TRUE)
#' @param overwrite Boolean determining if an existing file will be overwritten (Defaults to the safe FALSE)
#' @family File Functions
#' @return - 
#' @export
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' \dontrun{
#' # "Season 01" --> "S01" in current folder in MacOS Finder
#' umx_rename_file("[Ss]eason +([0-9]+)", replaceStr="S\1", baseFolder = "Finder", test = TRUE)
#' }
umx_rename_file <- function(findStr = NA, replaceStr = NA, baseFolder = "Finder", listPattern = NA, test = TRUE, overwrite = FALSE) {
	# TODO: umx_rename_file: Add recursive support
	if(is.na(replaceStr)){
		stop("Please set a replacement string")
	}
	# vain hope to work around R consuming \ characters
	# replaceStr = Hmisc::escapeRegex(replaceStr)
	if(baseFolder == "Finder"){
		baseFolder = system(intern = TRUE, "osascript -e 'tell application \"Finder\" to get the POSIX path of (target of front window as alias)'")
		message("Using front-most Finder window:", baseFolder)
	} else if(baseFolder == "") {
		baseFolder = paste(dirname(file.choose(new = FALSE)), "/", sep = "") ## choose a directory
		message("Using selected folder:", baseFolder)
	}
	if(is.na(listPattern)){
		listPattern = findStr
	}
	a = list.files(baseFolder, pattern = listPattern)
	message("found ", length(a), " possible files")
	changed = 0
	for (fn in a) {
		findB = grepl(pattern = findStr, fn) # returns 1 if found
		if(findB){
			fnew = gsub(findStr, replacement = replaceStr, x = fn) # replace all instances
			if(test){
				message("would change ", fn, " to ", fnew)
			} else {
				if((!overwrite) & file.exists(paste(baseFolder, fnew, sep = ""))){
					message("renaming ", fn, "to", fnew, "failed as already exists. To overwrite set T")
				} else {
					file.rename(paste0(baseFolder, fn), paste0(baseFolder, fnew))
					changed = changed + 1;
				}
			}
		}else{
			if(test){
				# message(paste("bad file",fn))
			}
		}
	}
	if(test & changed==0){
		message("add test = FALSE to actually change files.")
	} else {
		umx_msg(changed)
	}
}

#' dl_from_dropbox
#'
#' Download a file from Dropbox, given either the url, or the name and key
#'
#' Improvements would include error handling...
#' @param x Either the file name, or full dropbox URL (see example below)
#' @param key the code after s/ and before the file name in the dropbox url
#' @return - NULL
#' @export
#' @family File Functions
#' @references - \url{https://thebiobucket.blogspot.kr/2013/04/download-files-from-dropbox.html}
#' @examples
#' \dontrun{
#' dl_from_dropbox("https://dl.dropboxusercontent.com/s/7kauod48r9cfhwc/tinytwinData.rda")
#' dl_from_dropbox("tinytwinData.rda", key = "7kauod48r9cfhwc")
#' }
dl_from_dropbox <- function(x, key=NULL){
	# depends on RCurl::getBinaryURL
	if(is.null(key)){
		bin <- RCurl::getBinaryURL(x, ssl.verifypeer = FALSE)
		x = sub("^.+/(.*)$", "\\1", x, ignore.case = FALSE, perl = FALSE, fixed = FALSE, useBytes = FALSE)
	} else {
		# user has provided key and file name, so concatenate with https...
		bin <- RCurl::getBinaryURL(paste0("https://dl.dropboxusercontent.com/s/", key, "/", x), ssl.verifypeer = FALSE)
	}
	con <- file(x, open = "wb")
	writeBin(bin, con)
	close(con)
	message(noquote(paste(x, "read into", getwd())))
}

#' umx_pb_note
#'
#' Use the pushbullet service to push a note. You can also initialise this
#' service by providing your key one time
#'
#' If you supply auth_key, It will be written to "~/.pushbulletkey"
#' \code{\link{umx_pb_note}}(auth_key="mykeystring")
#' once it exists there, you do not need to store it in code, so code is sharable.
#' 
#' You can get your authorization key at \url{https://www.pushbullet.com} in 
#' the "account" section.
#' 
#' \strong{Note}: You can show the existing stored key using "GET"
#'
#' @param title of the note
#' @param body of the note
#' @param auth_key optional authkey (default = NA, set to value of your key to store key.
#' @export
#' @family Miscellaneous Utility Functions
#' @seealso - \code{\link{umx_msg}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' \dontrun{
#' umx_pb_note("done!", umx_time(m1))
#' }
umx_pb_note <- function(title = "test", body = "body", auth_key = c(NA, "GET")) {
	auth_key = match.arg(auth_key)
	auth_key_file = "~/.pushbulletkey"
	helpMsg = "auth_key not found. You need to call umx_pb_note one time with auth_key set. See ?umx_pb_note"
	if(is.na(auth_key)){
		umx_check(file.exists(auth_key_file), "message", helpMsg)
		auth_key = read.table(auth_key_file, stringsAsFactors=FALSE)[1,1]
	} else if(auth_key == "GET"){
		umx_check(file.exists(auth_key_file), "message", helpMsg)
		return(read.table(auth_key_file, stringsAsFactors=FALSE)[1,1])
	}else {
		fileConn <- file(auth_key_file)
		writeLines(auth_key, fileConn)
		close(fileConn)
		if(title=="test" && body=="default body"){
			title = "sucessfully setup umx_pb_note!"
			body = paste0("auth key is in ", omxQuotes(auth_key_file))
		}
	}
	cmd = paste0("curl -s --header 'Authorization: Bearer ", auth_key, "'", 
	" -X POST https://api.pushbullet.com/v2/pushes ",
	"--header 'Content-Type: application/json' ",
    "--data-binary '{\"type\": \"note\", \"title\": \"",title, "\", \"body\": \"", body, "\"}'"
	)
	invisible(system(cmd, intern=TRUE))
}

#' Move files
#'
#' On OS X, umx_move_file can access the current front-most Finder window.
#' The file moves are fast and, because you can use regular expressions, powerful.
#'
#' @param baseFolder  The folder to search in. If set to "Finder" (and you are on OS X) it will use the current front-most Finder window. If it is blank, a choose folder dialog will be thrown.
#' @param regex = regex string select files to move (WARNING: NOT IMPLEMENTED YET)
#' @param fileNameList List of files to move
#' @param destFolder Folder to move files into
#' @param test Boolean determining whether to change the names, or just report on what would have happened
#' @param overwrite Boolean determining whether to overwrite files or not (default = FALSE (safe))
#' @return - 
#' @family File Functions
#' @export
#' @examples
#' \dontrun{
#' base = "/Users/tim/Music/iTunes/iTunes Music/"
#' dest = "/Users/tim/Music/iTunes/iTunes Music/Music/"
#' umx_move_file(baseFolder = base, fileNameList = toMove, destFolder = dest, test= FALSE)
#' }
umx_move_file <- function(baseFolder = NA, regex = NULL, fileNameList = NA, destFolder = NA, test = TRUE, overwrite = FALSE) {
	# TODO umx_move_file: implement regular expressions to find files to move
	if(!is.null(regex)){
		stop("Have not implemented regex yet")
	}

	if(is.na(destFolder)){
		stop("destFolder can't be NA")
	}
	if(baseFolder == "Finder"){
		baseFolder = system(intern = TRUE, "osascript -e 'tell application \"Finder\" to get the POSIX path of (target of front window as alias)'")
		message("Using front-most Finder window:", baseFolder)
	} else if(baseFolder == "") {
		baseFolder = paste(dirname(file.choose(new = FALSE)), "/", sep="") ## choose a directory
		message("Using selected folder:", baseFolder)
	}
	moved = 0
	for (fn in fileNameList) {
		if(test){
			message("would move ", fn, " to ", destFolder)	
			moved = moved + 1;
		} else {
			if((!overwrite) & file.exists(paste0(destFolder, fn))){
				message("moving ", fn, "to", destFolder, "failed as already exists. To overwrite set T")
			} else {
				file.rename(paste0(baseFolder, fn), paste0(destFolder, fn))
				moved = moved + 1;
			}
		}
	}
	message("moved (or would have moved)", moved)
}

#' umx_open
#'
#' Open a file or folder. Works on OS X, mostly on windows, and hopefully on unix.
#'
#' NOTE: Your filepath is shQuoted by this function.
#' @param filepath The file to open
#' @return - 
#' @export
#' @family File Functions
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' \dontrun{
#' umx_open(getwd())
#' umx_open("~/bin/umx/R/misc_and_utility copy.r")
#' }
umx_open <- function(filepath = getwd()) {
	filepath = normalizePath(filepath)
	if (umx_check_OS("Windows")){
		shell(shQuote(filepath, type='cmd'), 'cmd.exe')
	} else {
		if(umx_check_OS("OSX")){
			opener = "open "
		} else { # *nix?
			opener = "xdg-open "
		}
		system(paste(opener, shQuote(filepath)))
	 # system2(opener, shQuote(filepath)) # possibly more robust.
	 # check when around multiple machine types
	}
}

#' umx_check_OS
#'
#' Check what OS we are running on (current default is OS X). Returns a boolean.
#' Optionally warn or die on failure of the test
#'
#' @param target Which OS(s) you wish to check for (default = "OSX")
#' @param action What to do on failure of the test: nothing (default), warn or die
#' @return - TRUE if on the specified OS (else FALSE)
#' @export
#' @family Test
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' umx_check_OS()
umx_check_OS <- function(target=c("OSX", "SunOS", "Linux", "Windows"), action = c("ignore", "warn", "die")) {
	action = match.arg(action)
	target = match.arg(target)
	# OSX == Darwin
	# Solaris == SunOS
	sysinfo <- Sys.info()
	if (!is.null(sysinfo)){
		os <- sysinfo['sysname']
		if (os == 'Darwin'){
			os <- "OSX"    	
		}
	} else {
		os <- .Platform$OS.type
		if (grepl("linux-gnu", R.version$os)){
		  os <- "Linux"	    	
		}
	}
	isTarget = (target == os)
	if(!isTarget){
		if(action == "die"){
			stop("Sorry: You must be running on ", target, " OS. You're on ", os)
		} else if(action == "warn"){
			message("i was expecting the OS to be ", target, " not ", os)
		}
	}
	return(isTarget)
}

#' Convert an excel spreadsheet in a text file on sql statements.
#'
#' Unlikely to be of use to anyone but the package author :-)
#' Read an xlsx file and convert into SQL insert statements (placed on the clipboard)
#' On MacOS, the function can access the current front-most Finder window.
#' 
#' The file name should be the name of the test.
#' Columns should be headed:
#' itemText	direction	scale	type	[optional	response	options]
#' 
#' The SQL fields generated are:
#' itemID, test, native_item_number, item_text, direction, scale, format, author
#' @details
#' tabbedPlus: list scored from 0 to n-1
#' 
#' tabbedVertPlus: tabbed, but vertical lay-out 
#' 
#' number	2+2<itemBreak>min='0' max='7' step='1'
#' 
#' 5fm Scored 1-5, anchored: Strongly Disagree | Disagree  | Neutral | Agree | Strongly Agree
#' 
#' intro (not) scored, and sequenced as item 0
#'
#' @param theFile The xlsx file to read. If set to "Finder" (and you are on OS X) it will use the current front-most Finder window. If it is blank, a choose file dialog will be thrown.
#' @family File Functions
#' @return - 
#' @export
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' \dontrun{
#' # An example Excel spreadsheet
#' # local uncompiled path
#' fp = system.file("inst/extdata", "GQ6.sql.xlsx", package = "umx")
#' # installed path
#' fp = system.file("extdata", "GQ6.sql.xlsx", package = "umx")
#' umx_open(fp)
#' umx_make_sql_from_excel() # Using file selected in front-most Finder window
#' umx_make_sql_from_excel("~/Desktop/test.xlsx") # provide a path
#' }
umx_make_sql_from_excel <- function(theFile = "Finder") {
	if(theFile == "Finder"){
		umx_check_OS("OSX")
		theFile = system(intern = TRUE, "osascript -e 'tell application \"Finder\" to get the POSIX path of (selection as alias)'")
		message("Using file selected in front-most Finder window:", theFile)
	} else if(theFile == "") {
		theFile = file.choose(new = FALSE) ## choose a file
		message("Using selected file:", theFile)
	} else if(theFile == "make") {
		theFile = system.file("extdata", "GQ6.sql.xlsx", package = "umx")
	}
	umx_check(file.exists(theFile), message= paste0("file:'", theFile, "' does not exist..."))
	# remove suffix (i.e., .xlsx )
	testName = umx_trim(basename(theFile), "\\..+$")
	
	df <- gdata::read.xls(theFile, sheet = 1, stringsAsFactors= FALSE)

	expect8 = c("itemText", "direction", "scale", "type")
	if(!all(expect8 %in% names(df))){
		stop(paste("I expected the following required column names:\n", omxQuotes(expect8), "\nYou gave me:", 
		    omxQuotes(names(df))), call. = FALSE)
	}

	nItems = dim(df)[1]
	nCols  = dim(df)[2]

	for (i in 1:nCols) {
		df[,i] = as.character(df[,i])
	}
	df[df == ""] = NA

	pre = "INSERT INTO Items VALUES ('"
	end = paste0("');")

	o = data.frame(sql="junk", stringsAsFactors = FALSE) ;
	itemNumber = 1
	for (lineNumber in 1:nItems) {
		direction  = df[lineNumber, "direction"]
		scale      = df[lineNumber, "scale"]
		type       = df[lineNumber, "type"]
		if (type=="info" & itemNumber == 1){
			# this will fail if there are two info questions at the top
			itemNumber = 0
		}
		itemText = df[lineNumber, "itemText"]
		# Any more cells in <itemBreak>?
		if(nCols > 5){
			items = df[lineNumber, 5:nCols]
			if(any(!is.na(items))){
				itemText = paste0(itemText, "<itemBreak>", paste(items[!is.na(items)], collapse = "<itemBreak>"))
			}
		}
		thisRow = paste(pre, testName, itemNumber, itemText, direction, scale, type, testName, end, sep = "', '")
		thisRow = umx_names(thisRow, pattern = ", '');", replacement = ");")
		o[itemNumber, ] = thisRow
		itemNumber = itemNumber + 1
	}
	umx_write_to_clipboard(x = o)
	message("sql is on clipboard")
}

#' umx_write_to_clipboard
#'
#' @description
#' umx_write_to_clipboard writes data to the clipboard
#'
#' @details
#' Works on Mac. Let me know if it fails on windows or Unix.
#' @param x something to put on the clipboard
#' @return - 
#' @export
#' @family String Functions
#' @family File Functions
#' @examples
#' \dontrun{
#' umx_write_to_clipboard("hello")
#' }
umx_write_to_clipboard <- function(x) {
	if(umx_check_OS("OSX")){
		clipboard <- pipe("pbcopy", "w")
		write.table(x, file = clipboard, sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
		close(clipboard)
	} else if (umx_check_OS("Windows")){
		write.table(x, file = "clipboard", sep = "\t", col.names = NA)
	}else{
		message("clipboard not implemented for *nix - awaiting a reliable solution. See:
		https://stackoverflow.com/questions/13438556/how-do-i-copy-and-paste-data-into-r-from-the-clipboard#13438558")
	}
}

# =========================
# = Various Stats helpers =
# =========================

#' Report correlations and their p-values
#'
#' For reporting correlations and their p-values in a compact table. Handles rounding, and skipping non-numeric columns.
#' 
#' To compute heterochoric correlations, see \code{\link{umxHetCor}}.
#'
#' note: The Hmisc package has a more robust function called rcorr 
#'
#' @param X a matrix or dataframe
#' @param df the degrees of freedom for the test
#' @param use how to handle missing data (defaults to pairwise complete)
#' @param digits rounding of answers
#' @param type Unused argument for future directions
#' @return - Matrix of correlations and p-values
#' @seealso umxHetCor
#' @family Miscellaneous Stats Helpers
#' @export
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' umx_cor(myFADataRaw[1:8,])
umx_cor <- function (X, df = nrow(X) - 2, use = c("pairwise.complete.obs", "complete.obs", "everything", "all.obs", "na.or.complete"), digits = 2, type= c("r and p-value", "smart")) {
	# see also
	# hmisc::rcorr( )
	use = match.arg(use)
	warning("TODO: umx_cor assumes no missing data, n is just nrow() !!")
	# nvar    = dim(x)[2]
	# nMatrix = diag(NA, nrow= nvar)
	# for (i in 1:nvar) {
	# 	x[,i]
	# }
	numericCols = rep(FALSE, ncol(X))
	for (i in 1:ncol(X)) {
		numericCols[i] = is.numeric(X[,i])
	}
	if(ncol(X) > sum(numericCols)){
		message("dropped ", ncol(X) - sum(numericCols), " non-numeric columns.")
	}
	
	R <- cor(X[,numericCols], use = use)
	above <- upper.tri(R)
	below <- lower.tri(R)
	r2 <- R[above]^2
	Fstat <- r2 * df/(1 - r2)
	R[row(R) == col(R)] <- NA # NA on the diagonal
	R[above] <- pf(Fstat, 1, df, lower.tail = FALSE)
	R[below] = round(R[below], digits)
	R[above] = round(R[above], digits)
	# R[above] = paste("p=",round(R[above], digits))
	message("lower tri  = correlation; upper tri = p-value")
	return(R)
}

# Return the maximum value in a row
rowMax <- function(df, na.rm = TRUE) {
	tmp = apply(df, MARGIN = 1, FUN = max, na.rm = na.rm)
	tmp[!is.finite(tmp)] = NA
	return(tmp)
}

rowMin <- function(df, na.rm= TRUE) {
	tmp = apply(df, MARGIN = 1, FUN = min, na.rm = na.rm)
	tmp[!is.finite(tmp)] = NA
	return(tmp)
}

#' umx_round
#'
#' A version of round() which works on dataframes that contain non-numeric data (or data that cannot be coerced to numeric)
#' Helpful for dealing with table output that mixes numeric and string types.
#'
#' @param df a dataframe to round in
#' @param digits how many digits to round to (defaults to getOption("digits"))
#' @param coerce whether to make the column numeric if it is not (default = FALSE)
#' @return - \code{\link{mxModel}}
#' @family Miscellaneous Stats Helpers
#' @export
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' head(umx_round(mtcars, coerce = FALSE))
#' head(umx_round(mtcars, coerce = TRUE))
#'
umx_round <- function(df, digits = getOption("digits"), coerce = FALSE) {
	if(is.matrix(df)){
		df = data.frame(df)
	}
	if(!is.data.frame(df)){
		if(is.null(dim(df))){
			if(coerce){
				return(round(as.numeric(df), digits))
			}else{
				return(round(df, digits))
			}
		} else {
			stop("df input for umx_round must be a dataframe")
		}
	}
	# for each column, if numeric, round
	rows = dim(df)[1]
	cols = dim(df)[2]
	for(c in 1:cols) {
		if(coerce){
			for(r in 1:rows) {
				df[r, c] = round(as.numeric(df[r, c]), digits)
			}
		} else {
			if(is.numeric(df[1, c])){
				df[ , c] = round(df[ , c], digits)
			}
		}
	}
	return(df)
}

#' Show model logLik of model or print comparison table
#'
#' @description
#' Just a helper to show the logLik of a model or print a comparison table is a function which 
#'
#' @param model an \code{\link{mxModel}} to report on
#' @param comparison If not NULL, used as comparison model
#' @param digits (default = 2)
#' @return - 
#' @export
#' @family Reporting Functions
#' @seealso - \code{\link{umxSummary}}
#' @examples
#' \dontrun{
#' umx_show_fit_or_comparison(model, comparison, digits=3)
#' }
#'
umx_show_fit_or_comparison <- function(model, comparison = NULL, digits = 2) {
	if(is.null(comparison)){
		# \u00d7 = times sign
		message(paste0(model$name, " -2 \u00d7 log(Likelihood) = ", 
			round(-2 * logLik(model), digits = digits))
		)
	} else {
		message("Comparison of model with parent model:")
		umxCompare(comparison, model, digits = digits)
	}		
}

specify_decimal <- function(x, k){
	format(round(x, k), nsmall = k)
}

#' reliability
#'
#' Compute and report Coefficient alpha (extracted from Rcmdr to avoid its dependencies)
#'
#' @param S A square, symmetric, numeric covariance matrix
#' @return - 
#' @export
#' @family Miscellaneous Stats Helpers
#' @references - \url{https://cran.r-project.org/package=Rcmdr}
#' @examples
#' # treat vehicle aspects as items of a test
#' reliability(cov(mtcars))
reliability <-function (S){
     reliab <- function(S, R) {
         k <- dim(S)[1]
         ones <- rep(1, k)
         v <- as.vector(ones %*% S %*% ones)
         alpha <- (k/(k - 1)) * (1 - (1/v) * sum(diag(S)))
         rbar <- mean(R[lower.tri(R)])
         std.alpha <- k * rbar/(1 + (k - 1) * rbar)
         c(alpha = alpha, std.alpha = std.alpha)
     }
     result <- list()
     if ((!is.numeric(S)) || !is.matrix(S) || (nrow(S) != ncol(S)) || any(abs(S - t(S)) > max(abs(S)) * 1e-10) || nrow(S) < 2)
         stop("argument must be a square, symmetric, numeric covariance matrix")
     k <- dim(S)[1]
     s <- sqrt(diag(S))
     R <- S/(s %o% s)
     rel <- reliab(S, R)
     result$alpha <- rel[1]
     result$st.alpha <- rel[2]
     if (k < 3) {
         warning("there are fewer than 3 items in the scale")
         return(invisible(NULL))
     }
     rel <- matrix(0, k, 3)
     for (i in 1:k) {
         rel[i, c(1, 2)] <- reliab(S[-i, -i], R[-i, -i])
         a <- rep(0, k)
         b <- rep(1, k)
         a[i] <- 1
         b[i] <- 0
         cov <- a %*% S %*% b
         var <- b %*% S %*% b
         rel[i, 3] <- cov/(sqrt(var * S[i, i]))
     }
     rownames(rel) <- rownames(S)
     colnames(rel) <- c("Alpha", "Std.Alpha", "r(item, total)")
     result$rel.matrix <- rel
     class(result) <- "reliability"
     result
}

print.reliability <- function (x, digits = 4, ...){
     cat(paste("Alpha reliability = ", round(x$alpha, digits), "\n"))
     cat(paste("Standardized alpha = ", round(x$st.alpha, digits), "\n"))
     cat("\nReliability deleting each item in turn:\n")
     print(round(x$rel.matrix, digits))
     invisible(x)
}


# ==================
# = Code functions =
# ==================
#' Install OpenMx, with choice of builds
#'
#' @description
#' You can install OpenMx, including the latest parallel/NPSOL enabled build of OpenMx. Options are:
#' 
#' 1. "NPSOL": Install from our repository (default: This is where we maintain binaries supporting parallel processing and NPSOL).
#' 
#' 2. "travis": Install the latest travis built (currently MacOS only).
#' 
#' 3. "CRAN": Install from CRAN.
#' 
#' 4. "open travis build page": Open the list of travis builds in a browser window.
#'
#' @aliases umx_update_OpenMx
#' @param loc Which install to get: "UVa" (the default), "travis" (latest build),
#' or open the travis list of builds on the web to view/pick a url.
#' @param url A custom URL if you have/need one (probably not). If you're on a Mac, you can set this to "Finder" and the package selected in the Finder will be installed. Overrides other settings.
#' @param repos Which repository to use (ignored currently).
#' @param lib Where to install the package.
#' @return - 
#' @export
#' @seealso \code{\link{umxVersion}}
#' @family Miscellaneous Utility Functions
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' \dontrun{
#' install.OpenMx() # gets the NPSOL version
#' install.OpenMx("NPSOL") # gets the NPSOL version explicitly
#' install.OpenMx("CRAN") # Get the latest CRAN version
#' install.OpenMx("open travis build page") # Open web page of travis builds
#' }
install.OpenMx <- function(loc = c("NPSOL", "travis", "CRAN", "open travis build page", "UVa"), url= NULL, lib, repos = getOption("repos")) {	
	loc = match.arg(loc)
	if(loc == "UVa"){
		loc = "NPSOL"
		message("next time, use 'NPSOL' instead of 'UVa'")
	}
	
	if(!is.null(url)){
		if(url == "Finder"){
			umx_check_OS("OSX")
			url = system(intern = TRUE, "osascript -e 'tell application \"Finder\" to get the POSIX path of (selection as alias)'")
			message("Using file selected in front-most Finder window:", url)
		} else if(url == "") {
			url = file.choose(new = FALSE) ## choose a file
			message("Using selected file:", url)
		}
		install.packages(url)
	} else if(loc == "NPSOL"){
		if(umx_check_OS("Windows")){
			detach('package:OpenMx', unload = TRUE)
		}
		source("https://openmx.ssri.psu.edu/getOpenMx.R")
		# was source("https://openmx.ssri.psu.edu/software/getOpenMx.R")
		# was https://openmx.psyc.virginia.edu/getOpenMx.R
		# was source("https://openmx.ssri.psu.edu/software/getOpenMx.R")		
	}else if(loc == "travis"){
		if(umx_check_OS("OSX")){
			install.packages("https://vipbg.vcu.edu/vipbg/OpenMx2/software/bin/macosx/travis/OpenMx_latest.tgz")
			# was ("https://openmx.psyc.virginia.edu/OpenMx2/bin/macosx/travis/OpenMx_latest.tgz")
			# , lib = lib, repos=repos
		} else {
			stop(paste0("Sorry, travis builds are only available for MacOS :-("))
		}
	} else if(loc == "CRAN"){
		install.packages("OpenMx", lib= lib, repos = repos)
	} else if(loc == "open travis build page"){
		browseURL("https://vipbg.vcu.edu/vipbg/OpenMx2/software/bin/macosx/travis")
	}
}

#' @export
umx_update_OpenMx <- install.OpenMx

#' "make" the umx package using devtools: release to CRAN etc.
#'
#' @description
#' Easily  run devtools "install", "release", "win", "examples" etc.
#'
#' @param what whether to "install", "release" to CRAN, check on "win", "check", "rhub", "spell" check, or check "examples"))
#' @param pkg the local path to your package. Defaults to my path to umx.
#' @param check Whether to run check on the package before release (default = TRUE).
#' @param spelling Whether to check spelling before release (default = "en_US": set NULL to not check).
#' @return - 
#' @export
#' @family Miscellaneous Utility Functions
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' \dontrun{
#' umx_make(what = "install"))  # just installs the package
#' umx_make(what = "examples")) # run the examples
#' umx_make(what = "check"))    # run R CMD check
#' umx_make(what = "win"))      # check on win-builder
#' umx_make(what = "release"))  # release to CRAN
#' }
umx_make <- function(what = c("install", "examples", "check", "win", "rhub", "release", "spell"), pkg = "~/bin/umx", check = TRUE, spelling = "en_US") {
	what = match.arg(what)
	if(what == "install"){
		devtools::document(pkg = pkg); devtools::install(pkg = pkg);
	} else if(what == "examples"){
		devtools::run_examples(pkg = pkg)
	} else if(what == "check"){
		# http://r-pkgs.had.co.nz/check.html
		devtools::check(pkg = pkg)		
	} else if (what =="win"){
		# old =
		devtools::build_win(pkg = pkg)

		# new =
		# devtools::check_win_devel(pkg = pkg)
	} else if (what =="rhub"){
		# devtools::check_rhub(pkg = pkg)
	} else if (what == "release"){
		devtools::release(pkg = pkg, check = check) # spelling = spelling
	} else if (what == "spell"){
		devtools::spell_check(pkg = pkg)
	}
}

# ==============================
# = User interaction functions =
# ==============================

#' Print the name and compact contents of variable.
#'
#' Helper function to make dumping  "ObjectName has the value: <objectvalue>" easy.
#' This is primarily useful for inline debugging, where seeing "nVar = NULL" can be useful,
#' and the code \code{umxMsg(nVar)} makes this easy.
#'
#' @param  x the thing you want to pretty-print
#' @return - NULL
#' @export
#' @family Miscellaneous Utility Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' a = "brian"
#' umx_msg(a)
#' b = c("brian", "sally", "jane")
#' umx_msg(b)
#' umx_msg(mtcars)
umx_msg <- function(x) {
	nm = deparse(substitute(x) )
	if(is.data.frame(x)){
		message(nm, " = ")
		str(x)
	} else {
		if(length(x) > 1) {
			message(nm, " = ", omxQuotes(x))	
		} else {
			message(nm, " = ", x)	
		}
	}
}

# ====================
# = String Functions =
# ====================
#' Concatenate base variable names with suffixes to create wide-format variable names (i.e twin-format)
#'
#' @description
#' It's easier to work with base names, rather than the twice-as-long hard-to-typo list of column names.
#' `umx_paste_names` adds suffixes to names so you can work with that nice short list.
#' So, you provide `bmi`, and you get back fully specified family-wise names: `c("bmi_T1", "bmi_T2")`
#' 
#' *note*: `tvars` is a shortcut for `umx_paste_names`
#' 
#' @details
#' **Method 1**: *Use complete suffixes*
#' 
#' You can provide complete suffixes like "_T1" and "_T2". This has the benefit of being explicit
#' and very general:
#'
#'     umx_paste_names(c("var1", "var2"), suffixes = c("_T1", "_T2"))
#'
#' *Note*: for quick typing, `tvars` is an alias for `umx_paste_names`
#'
#' **Method 2**: *Use sep and a suffix vector.*
#' 
#' Alternatively, you can use `sep` to add a constant like "_T" after each basename, along
#' with a vector of suffixes. This has the benefit of showing what is varying:
#' This is then suffixed with e.g. "1", "2".
#'
#'     umx_paste_names(c("var1", "var2"), sep = "_T", suffixes = 1:2)
#'
#' *Working with covariates*
#' 
#' If you are using \code{\link{umxACEcov}}, you **need** to keep all the covariates at the end of the list.
#' Here's how:
#' 
#'     umx_paste_names(c("var1", "var2"), cov = c("cov1"), sep = "_T", suffixes = 1:2)
#' 
#' *note*: in conventional twin models, the expCov matrix is T1 vars, followed by T2 vars. For covariates, you want
#' T1vars, T2 vars, T1 covs, T2 covs. This is what `covNames` accomplishes.
#' @aliases tvars
#' @param varNames a list of _base_ names, e.g c("bmi", "IQ")
#' @param sep A string separating the name and the twin suffix, e.g. "_T" (default is "")
#' @param suffixes a list of terminal suffixes differentiating the twins default = c("1", "2"))
#' @param covNames a list of _base_ names for covariates (sorted last in list), e.g c("age", "sex")
#' @param prefix a string to pre=pend to each label, e.g c("mean_age", "mean_sex")
#' @return - vector of suffixed var names, i.e., c("v1_T1", "v2_T1", "v1_T2", "v2_T2", "cov_T1", "cov_T2")
#' @export
#' @family String Functions
#' @seealso \code{\link{namez}}
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' # two styles doing the same thing: first is more general
#' umx_paste_names("bmi", suffixes = c("_T1", "_T2"))
#' umx_paste_names("bmi", sep = "_T", suffixes = 1:2)
#' varNames = umx_paste_names(c("N", "E", "O", "A", "C"), "_T", 1:2)
#' umx_paste_names(c("IQ", "C"), cov = c("age"), sep = "_T", suffixes = 1:2)
#' umx_paste_names(c("IQ", "C"), cov = c("age"), sep = "_T", prefix= "mean_")
#' # For quick-typing, tvars is an alias for umx_paste_names
#' tvars(c("IQ", "C"), cov = c("age"), sep = "_T", prefix= "mean_")
#' @md
umx_paste_names <- function(varNames, sep = "", suffixes = 1:2, covNames = NULL, prefix = NULL) {
	nameList = c()
	for (ID in suffixes) {
		nameList = c(nameList, paste0(varNames, sep, ID))
	}
	if(!is.null(covNames)){
		for (ID in suffixes) {
			nameList = c(nameList, paste0(covNames, sep, ID))
		}
	}

	if(!is.null(prefix)){
		nameList = paste0(prefix, nameList)
	}
	return(nameList)
}
#' @export
tvars <- umx_paste_names

#' umx_merge_CIs
#'
#' if you compute some CIs in one model and some in another (copy of the same model, perhaps to get some parallelism),
#' this is a simple helper to kludge them together.
#'
#' @param m1 first copy of the model
#' @param m2 second copy of the model
#' @return - \code{\link{mxModel}}
#' @family zAdvanced Helpers
#' @export
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' \dontrun{
#' umx_merge_CIs(m1, m2)
#' }
umx_merge_CIs <- function(m1, m2) {
	# TODO umx_merge_CIs has 5 things todo :-(
	# 1. remove duplicates...
	# 2. (check they are the same as well!)
	# 3. Support arbitrarily long list of input models with ...
	# 4. check the models are the same, with same fit
	# 5. check the models have CIs
	# kluge together
	a  = m1$output$confidenceIntervals
	b  = m2$output$confidenceIntervals
	a_names = attr(a, "dimnames")[[1]]
	b_names = attr(b, "dimnames")[[1]]
	all_names = c(a_names, b_names)
	all_CIs = rbind(a,b)
	if(any(duplicated(all_names))){
		message("Some CIs appear to be duplicates...")
		message("I dropped these from the list:")
		cat(duplicated(all_names))
		cat(all_names[duplicated(all_names)])
		cat(all_CIs[duplicated(all_names), ])
	}

	m1$output$confidenceIntervals = all_CIs
	return(m1)
	# return(all_CIs)
}

# =====================
# = Statistical tools =
# =====================

#' Convert a dataframe into a cov mxData object
#'
#' umxCovData converts a dataframe into an mxData, taking the covariance, defaulting to nrow as the numObs,
#' and optionally adding means.
#'
#' @param df the dataframe to covert to an mxData type cov object.
#' @param columns = Which columns to keep (default is all).
#' @param use = Default is "complete.obs".
#' @return - \code{\link{mxData}} of type = cov
#' @export
#' @family Data Functions
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' umxCovData(mtcars, c("mpg", "hp"))
umxCovData <- function(df, columns = NA, use = c("complete.obs", "everything", "all.obs", "na.or.complete", "pairwise.complete.obs")) {
	# TODO umxCovData: Use 'use' to compute numObs in umxCovData
	use = match.arg(use)
	if(anyNA(columns)){
		columns = names(df)
	}
	df = df[,columns]
	if(use == "complete.obs"){
		df = df[complete.cases(df), ]
	} else {
		if(anyNA(df)){
			message("numObs was set to nrow, but if as the data contain NAs, this is too liberal!")
		}
	}
	numObs = nrow(df)
	umx_check_names(columns, df)
	return(mxData(cov(df[, columns], use = use), type = "cov", numObs = numObs))
}

#' Convert a covariance matrix into a correlation matrix
#'
#' umxCov2cor like \code{\link{cov2cor}} that forces upper and lower triangles to be identical (rather than nearly identical)
#'
#' @param x something that cov2cor can work on (matrix, df, etc.)
#' @return - a correlation matrix
#' @export
#' @family Miscellaneous Stats Helpers
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' umxCov2cor(cov(mtcars))
umxCov2cor <- function(x) {
	x = cov2cor(x)
	x[lower.tri(x)] <- t(x)[lower.tri(t(x))]
	return(x)
}


# ================================
# = Reporting & Graphing helpers =
# ================================

#' umx_show
#'
#' Show matrix contents. The user can select  values, free, and/or labels, and which matrices to display
#'
#' @param model an \code{\link{mxModel}} to show data from
#' @param what legal options are "values" (default), "free", or "labels")
#' @param show filter on what to show c("all", "free", "fixed")
#' @param matrices to show  (default is c("S", "A")). "Thresholds" in beta
#' @param digits precision to report, defaults to rounding to 2 decimal places
#' @return - \code{\link{mxModel}}
#' @export
#' @family Reporting Functions
#' @references - \url{https://tbates.github.io}
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
#' umx_show(m1)
#' umx_show(m1, digits = 3)
#' umx_show(m1, matrices = "S")
#' umx_show(m1, what = "free")
#' umx_show(m1, what = "labels")
#' umx_show(m1, what = "free", matrices = "A")
umx_show <- function(model, what = c("values", "free", "labels", "nonzero_or_free"), show = c("all", "free", "fixed"), matrices = c("S", "A"), digits = 2) {
	if(!umx_is_RAM(model)){
		stop("Only RAM models by default: what would you like me to do with this type of model?")
	}
	what = match.arg(what)
	show = match.arg(show)
	
	if("thresholds" %in% matrices){
		# TODO umx_show: Threshold printing not yet finalized
		if(!is.null(model$deviations_for_thresh)){
			dev = TRUE
			x = model$deviations_for_thresh
		} else {
			dev = FALSE
			x = model$threshMat
		}
		if(what == "values"){
			if(dev){
				v = model$lowerOnes_for_thresh$values %*% x$values
			} else {
				v = x$values
			}
			if(show == "free"){
				v[x$free == FALSE] = NA
			} else if (show == "fixed") {
				v[x$free == TRUE] = NA
			}
			umx_print(v, zero.print = ".", digits = digits)		
		}else if(what == "free"){
			umx_print(data.frame(x$free) , zero.print = ".", digits = digits)
		}else if(what == "labels"){
			l = x$labels
			if(show == "free"){
				l[x$free == FALSE] = ""
			} else if (show=="fixed") {
				l[x$free == TRUE] = ""
			}
			umx_print(l, zero.print = ".", digits = digits)
		}
	} else {
		for (w in matrices) {
			message("Showing ", what, " for:", w, " matrix:")
			if(what == "values"){
				umx_print(data.frame(model$matrices[[w]]$values), zero.print = ".", digits = digits)		
			}else if(what == "free"){
				umx_print(data.frame(model$matrices[[w]]$free) , zero.print = ".", digits = digits)
			}else if(what == "labels"){
				x = model$matrices[[w]]$labels
				if(show=="free"){
					x[model$matrices[[w]]$free!=TRUE] = ""
				} else if (show=="fixed") {
					x[model$matrices[[w]]$free==TRUE] = ""
				}
				umx_print(x, zero.print = ".", digits = digits)
			}else if(what == "nonzero_or_free"){
				message("99 means the value is fixed, but is non-zero")
				values = model$matrices[[w]]$values
				Free   = model$matrices[[w]]$free
				values[!Free & values !=0] = 99
				umx_print(data.frame(values) , zero.print = ".", digits = digits)
			}
		}
	}
}

#' umx_time
#'
#' A function to compactly report how long a model took to execute. Comes with some preset styles
#' User can set the format with C-style string formatting.
#'
#' The default time format is "simple", which gives only the biggest unit used. i.e., "x seconds" for times under 1 minute.
#' "std" shows time in the format adopted in OpenMx 2.0 e.g. "Wall clock time (HH:MM:SS.hh): 00:00:01.16"
#' 
#' If a list of models is provided, time deltas will also be reported.
#' 
#' If instead of a model the key word "start" is given in x, a start time will be recorded. "stop" gives the
#' time since "start" was called (and clears the timer)
#' 
#' If a model has not been run, umx_time will run it for you.
#'
#' @param x A \code{\link{mxModel}} or list of models for which to display elapsed time, or 'start' or 'stop'
#' @param formatStr A format string, defining how to show the time (defaults to human readable)
#' @param tz time zone in which the model was executed (defaults to "GMT")
#' @param autoRun If TRUE (default), run the model if it appears not to have been.
#' @return - invisible time string
#' @export
#' @family Reporting Functions
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' require(umx)
#' umx_time('start')
#' data(demoOneFactor)
#' latents  = c("G")
#' manifests = names(demoOneFactor)
#' myData = mxData(cov(demoOneFactor), type = "cov", numObs = 500)
#' m1 <- umxRAM("One Factor", data = myData,
#' 	umxPath(from = latents, to = manifests),
#' 	umxPath(var = manifests),
#' 	umxPath(var = latents, fixedAt = 1)
#' )
#' umx_time(m1)
#' m2 = umxRun(m1)
#' umx_time(c(m1, m2))
#' umx_time('stop')
#' # elapsed time: .3 seconds
umx_time <- function(x = NA, formatStr = c("simple", "std", "custom %H %M %OS3"), tz = "GMT", autoRun = TRUE){
	if(is.list(x)){
		# check each item is a model
		if(!umx_is_MxModel(x, listOK = TRUE)){
			stop("If x is a list of models, each must be a valid mxModel")
		}
	}else if(umx_is_MxModel(x)){
		# great, we've got a model?
	}else if(is.character(x)){
		umx_check(x %in% c('start', 'stop'), "stop", "Valid time strings are 'start', 'stop' (or a model or list of models)")
	}else if(is.na(x)){
		stop("You must set the first parameter (options are 'start', 'stop', a model, or a list of models)")
	}else{
		stop("You must set the first parameter to 'start', 'stop', a model, or a list of models.\nYou offered up a", class(x))
	}
	formatStr = umx_default_option(formatStr, c("simple", "std", "custom %H %M %OS3"), check = FALSE)
	# TODO umx_time: Improve table formating
	for(i in 1:length(x)) {			
		if(length(x) > 1) {
			m = x[[i]]
		} else {
			if(class(x) == "list"){
				m = x[[i]]
			} else {
				m = x
			}
		}
		if(class(m) == "character"){
			if(m == "start"){
				options("umx_last_time" = proc.time())
				return(invisible())
			} else if (m == "stop") {
				thisTime = (proc.time()["elapsed"] - getOption("umx_last_time")["elapsed"])
				options("umx_last_time" = proc.time())
			}else{
				stop("Value strings for umx_time are start and stop, not: ", omxQuotes(m))
			}
		} else {
			# handle model
			if(!umx_has_been_run(m) && autoRun){
				m = mxRun(m)
				# message("You must run the model before asking for the elapsed run time")
			}
			thisTime = m$output$wallTime
			if(i == 1){
				lastTime = thisTime
				timeDelta = ""
			} else {
				timeDelta = paste0("(\u2206: ", round(thisTime - lastTime, 3), ")")
			}
		}
		if(formatStr == "std"){
			formatStr = "Wall clock time (HH:MM:SS.hh): %H:%M:%OS2"
		} else if(formatStr == "simple"){
			if(thisTime > (3600 * 2) - 1){ # hours
				formatStr = "%H hours, %M minute(s), %OS2 seconds"
			} else if(thisTime > 3600){ # hours
				formatStr = "%H hour, %M minute(s), %OS2 seconds"
			} else if(thisTime > 60){ # minutes
				if(thisTime > 119){ # minutes
					formatStr = "%M minutes,  %OS2 seconds"
				}else{
					formatStr = "%M minute,  %OS2 seconds"	
				}					
			} else { # seconds
				formatStr = "%OS2 seconds"
			}
		}
		
		if(class(m) == "character"){
			timeString = format(.POSIXct(thisTime, tz), paste0("elapsed time: ", formatStr))
		} else {
			timeString = format(.POSIXct(thisTime, tz), paste0(m$name, ": ", formatStr, timeDelta))
		}
		message(timeString)
	}
	invisible(timeString)
}



#' Print tables in a range of formats (markdown default, see \code{\link{umx_set_table_format}} for other formats)
#' or as a web browser table.
#'
#' To aid interpretability of printed tables from OpenMx (and elsewhere)
#' you can change how NA and zero appear, and suppressing values below a certain cut-off.
#' By default, Zeros have the decimals suppressed, and NAs are suppressed altogether.
#'
#' @param x A data.frame to print (matrices will be coerced to data.frame)
#' @param digits  The number of decimal places to print (defaults to getOption("digits")
#' @param quote  Parameter passed to print (defaults to FALSE)
#' @param na.print String to replace NA with (default to blank "")
#' @param zero.print String to replace 0.000 with  (defaults to "0")
#' @param justify Parameter passed to print (defaults to "none")
#' @param file whether to write to a file (defaults to NA (no file). Use "tmp.html" to open table in browser.
#' @param suppress minimum numeric value to print (default =  NULL, print all values, no matter how small)
#' @param ... Optional parameters for print
#' @return - A dataframe of text
#' @export
#' @seealso \code{\link{umx_msg}}, \code{\link{umx_set_table_format}} 
#' @family Miscellaneous Utility Functions
#' @family Reporting Functions
#' @examples
#' umx_print(mtcars[1:10,], digits = 2, zero.print = ".", justify = "left")
#' umx_print(mtcars[1,1:2], digits = 2, zero.print = "")
#' \dontrun{
#' umx_print(mtcars[1:10,], file = "tmp.html")
#' }
umx_print <- function (x, digits = getOption("digits"), quote = FALSE, na.print = "", zero.print = "0", justify = "none", file = c(NA, "tmp.html"), suppress = NULL, ...){
	# depends on R2HTML::HTML and knitr::kable
	file = umx_default_option(file, c(NA,"tmp.html"), check = FALSE)
	if(class(x)=="character"){
		print(x)
	}else if(class(x)!= "data.frame"){
		if(class(x)=="matrix" |class(x)=="numeric"){
			x = data.frame(x)
		} else {
			message("Sorry, umx_print currently only prints data.frames, matrices, and vectors.\n
			File a request to print '", class(x), "' objects\n or perhaps you want umx_msg?")
			return()
		}
	}

	if(is.null(dim(x)[1]) || dim(x)[1] == 0){
		return()
	} else {
		if(!is.null(suppress)){
			x[abs(x) < suppress] = 0
			zero.print = "."
		}
		x <- umx_round(x, digits = digits, coerce = FALSE)
	    if (any(ina <- is.na(x))) 
	        x[ina] <- na.print
			i0 <- !ina & x == 0
	    if (zero.print != "0" && any(i0)) 
	        x[i0] <- zero.print
	    if (is.numeric(x) || is.complex(x)){
	        print(x, quote = quote, right = TRUE, ...)
		} else if(!is.na(file)){
				R2HTML::HTML(x, file = file, Border = 0, append = FALSE, sortableDF= TRUE); 
				system(paste0("open ", file))
				print("Table opened in browser")
	    }else{
				print(knitr::kable(x))
	    }
	    invisible(x)
	}
} # end umx_print

# ===========================
# = Boolean check functions =
# ===========================

#' umx_has_been_run
#'
#' check if an mxModel has been run or not
#'
#' @param model The \code{\link{mxModel}} you want to check has been run
#' @param stop  Whether to stop if the model has not been run (defaults to FALSE)
#' @return - boolean
#' @export
#' @family Test
#' @references - \url{https://www.github.com/tbates/umx}
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
#' umx_has_been_run(m1)
umx_has_been_run <- function(model, stop = FALSE) {
	output <- model$output
	if (is.null(output)){
		if(stop){
			stop("Provided model has no objective function, and thus no output to process further")
		}else{
			return(FALSE)
		}
	} else if (length(output) < 1){
		if(stop){
			stop("Provided model has no output (probably you have not yet run it?)")
		} else {
			return(FALSE)
		}
	}
	return(TRUE)
}

umxCheckModel <- function(model){
	# Are all the manifests in paths?
	# Do the manifests have residuals?
	if(any(duplicated(model@manifestVars))){
		stop(paste("manifestVars contains duplicates:", duplicated(model@manifestVars)))
	}
	if(length(model@latentVars) == 0){
		# Check none are duplicates, none in manifests
		if(any(duplicated(model@latentVars))){
			stop(paste("latentVars contains duplicates:", duplicated(model@latentVars)))
		}
		if(any(duplicated(c(model@manifestVars, model@latentVars)))){
			stop(
				paste("manifest and latent lists contain clashing names:", duplicated(c(model@manifestVars, model@latentVars)))
			)
		}
	}
	# Check manifests in dataframe
}

#' umx_check
#'
#' Check that a test evaluates to TRUE. If not, stop, warn, or message the user
#'
#' @param boolean.test test evaluating to TRUE or FALSE
#' @param action One of "stop" (the default), "warning", or "message"
#' @param message what to tell the user when boolean.test is FALSE
#' @return - boolean
#' @export
#' @family Test
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' umx_check(length(1:3)==3, "stop", "item must have length == 3")
umx_check <- function(boolean.test, action = c("stop", "warning", "message"), message = "check failed"){
	action = match.arg(action)
	if(!boolean.test){
		if(action == "stop"){
			stop(message, call. = FALSE)
		} else if(action == "warning"){
			warning(message, call. = FALSE)
		}else{
			message(message)			
		}
	}
	return(boolean.test)
}

#' umx_check_names
#'
#' Check if a list of names are in the names() of a dataframe (or the of a matrix)
#'
#' @param namesNeeded list of variable names to find (a dataframe is also allowed)
#' @param data data.frame (or matrix) to search in for names (default = NA)
#' @param die whether to die if the check fails (defaults to TRUE)
#' @param no_others Whether to test that the data contain no columns in addition to those in namesNeeded (defaults to FALSE)
#' @param intersection Show the intersection of names
#' @param message Some helpful text to append when dieing.
#' @family Test
#' @export
#' @family Check or test
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(demoOneFactor) # "x1" "x2" "x3" "x4" "x5"
#' umx_check_names(c("x1", "x2"), demoOneFactor)
#' umx_check_names(c("x1", "x2"), as.matrix(demoOneFactor))
#' umx_check_names(c("x1", "x2"), cov(demoOneFactor[, c("x1","x2")]))
#' umx_check_names(c("z1", "x2"), data = demoOneFactor, die = FALSE)
#' umx_check_names(c("x1", "x2"), data = demoOneFactor, die = FALSE, no_others = TRUE)
#' umx_check_names(c("x1","x2","x3","x4","x5"), data = demoOneFactor, die = FALSE, no_others = TRUE)
#' \dontrun{
#' umx_check_names(c("bad_var_name", "x2"), data = demoOneFactor, die = TRUE)
#' }
umx_check_names <- function(namesNeeded, data = NA, die = TRUE, no_others = FALSE, intersection = FALSE, message = ""){
	if(is.data.frame(namesNeeded)){
		namesNeeded = names(namesNeeded)
	}else if(is.matrix(namesNeeded)){
		namesNeeded = dimnames(namesNeeded)[[2]]
	} else if (typeof(namesNeeded)=="character"){
		namesNeeded = namesNeeded
	} else{
		stop("namesNeeded has to be a list of names, a dataframe or matrix. You gave me a ", typeof(namesNeeded))
	}
	if(is.data.frame(data)){
		namesInData = names(data)
	}else if(is.matrix(data)){
		namesInData = dimnames(data)[[2]]
	} else if (!typeof(data) == "character"){
		namesInData = data
	} else {
		stop("data has to be a dataframe or matrix. You gave me a ", typeof(data))
	}
	if(intersection){
		namesFound = intersect(namesNeeded, namesInData)
		message(paste(namesFound, ", "))
	} else {
		namesFound = (namesNeeded %in% namesInData)
		if(any(!namesFound)){
			if(die){
				# print(namesInData[namesFound])
				stop("Not all required names were found in the data. Missing were:\n",
					paste(namesNeeded[!namesFound], collapse = "; "), "\n", message
				)
			} else {
				return(FALSE)
			}
		} else if(no_others & !setequal(namesInData, namesNeeded)){
			if(die){
				stop("Data contains columns other than those needed. Superfluous columns were:\n", 
					paste(namesInData[!namesInData %in% namesNeeded], collapse = "; "))
			} else {
				return(FALSE)
			}
		} else {
			return(TRUE)
		}
	}
}

#' Get variances from a df that might contain some non-numeric columns
#'
#' Pass in any dataframe and get variances despite some non-numeric columns.
#' Cells involving these non-numeric columns are set to ordVar (default = 1).
#'
#' @param df A dataframe of raw data from which to get variances.
#' @param ordVar The value to return at any ordinal columns (defaults to 1).
#' @param format to return: options are c("full", "diag", "lower"). Defaults to full, but this is not implemented yet.
#' @param use Passed to \code{\link{cov}} - defaults to "complete.obs" (see param default for other options).
#' @param digits Ignored if NULL. Set for easy printing.
#' @param strict Whether to allow non-ordered factors to be processed (default = FALSE (no)).
#' @return - \code{\link{mxModel}}
#' @export
#' @family Miscellaneous Stats Helpers
#' @references - \url{https://tbates.github.io}
#' @examples
#' tmp     = mtcars[,1:4]
#' tmp$cyl = ordered(mtcars$cyl) # ordered factor
#' tmp$hp  = ordered(mtcars$hp)  # binary factor
#' umx_var(tmp, format = "diag", ordVar = 1, use = "pair")
#' tmp2 = tmp[, c(1, 3)]
#' umx_var(tmp2, format = "diag")
#' umx_var(tmp2, format = "full")
umx_var <- function(df, ordVar = 1, format = c("full", "diag", "lower"), use = c("complete.obs", "pairwise.complete.obs", "everything", "all.obs", "na.or.complete"), digits = NULL, strict = TRUE){
	format = match.arg(format)
	use    = match.arg(use)
	if(any(umx_is_ordered(df, strict = strict))){
		nCol = dim(df)[2]
		out  = diag(ordVar, nCol, nCol)
		cont = umx_is_ordered(df, continuous.only = TRUE)
		if(any(cont)){
			for(i in which(cont)) {
				out[i,i] = var(df[,i], use = use)
			}
		}
		if(format == "diag"){
			return(diag(out))
		} else {
			stop("Only diag implemented yet for umx_var")
			return(out)	
		}
	} else {
		full = var(df, use = use)
		if(format == "full"){
			out = full
		} else if(format == "diag") {
			out = diag(full)
		} else {
		 # "lower"
			out = diag(full)
		}
		if(!is.null(digits)){
			return(round(out, digits))
		} else {
			return(out)
		}
	}
}

#' umx_means
#'
#' Helper to get means from a df that might contain ordered or string data.
#' Factor means are set to "ordVar"
#'
#' @param df a dataframe of raw data from which to get variances.
#' @param ordVar value to return for the means of factor data = 0
#' @param na.rm passed to mean - defaults to "na.rm"
#' @return - frame of means
#' @export
#' @family Miscellaneous Stats Helpers
#' @examples
#' tmp = mtcars[,1:4]
#' tmp$cyl = ordered(mtcars$cyl) # ordered factor
#' tmp$hp  = ordered(mtcars$hp)  # binary factor
#' umx_means(tmp, ordVar = 0, na.rm = TRUE)
umx_means <- function(df, ordVar = 0, na.rm = TRUE) {
	if(!is.data.frame(df)){
		if(is.matrix(df)){
			df = data.frame(df)
		} else {
			stop("argument df must be a dataframe. You gave me a ", class(df), ". Perhaps this is one column selected from a data frame without [r,c, drop=FALSE]? ")
		}
	}
	if(any(umx_is_ordered(df, strict = FALSE))){
		# Set the default outcome
		means = rep(ordVar, times = dim(df)[2])
		# Get variables where mean makes sense
		cont = umx_is_ordered(df, continuous.only = TRUE, strict = FALSE)
		if(any(cont)){
			for(i in which(cont)) {
				means[i] = mean(df[, i], na.rm = na.rm)
			}
		}
	} else {
		means = umx_apply(mean, df, by = "columns", na.rm = TRUE)
	}
	return(means)
}

#' Check if an object is an mxData object
#'
#' Is the input an MxData?
#'
#' @param x An object to test for being an MxData object
#' @return - Boolean
#' @export
#' @family Test
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' umx_is_MxData(mtcars)
#' umx_is_MxData(mxData(mtcars, type= "raw"))
#' umx_is_MxData(mxData(cov(mtcars), type= "cov", numObs = 73))
umx_is_MxData <- function(x) {
    if(class(x)[1] %in%  c("MxNonNullData", "MxDataStatic") ) {
		TRUE
	} else {
		FALSE
	}
}

#' Test if one or more variables in a dataframe are ordered
#'
#' Return the names of any ordinal variables in a dataframe
#'
#' @param df A \code{\link{data.frame}} to look in for ordinal variables (if you offer a
#' matrix or vector, it will be upgraded to a dataframe)
#' @param names whether to return the names of ordinal variables, or a binary (T,F) list (default = FALSE)
#' @param strict whether to stop when unordered factors are found (default = TRUE)
#' @param binary.only only count binary factors (2-levels) (default = FALSE)
#' @param ordinal.only only count ordinal factors (3 or more levels) (default = FALSE)
#' @param continuous.only use with names = TRUE to get the names of the continuous variables
#' @return - vector of variable names or Booleans
#' @export
#' @family Test
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' tmp = mtcars
#' tmp$cyl = ordered(mtcars$cyl) # ordered factor
#' tmp$vs = ordered(mtcars$vs) # binary factor
#' umx_is_ordered(tmp) # numeric indices
#' umx_is_ordered(tmp, names = TRUE)
#' umx_is_ordered(tmp, names = TRUE, binary.only = TRUE)
#' umx_is_ordered(tmp, names = TRUE, ordinal.only = TRUE)
#' umx_is_ordered(tmp, names = TRUE, continuous.only = TRUE)
#' umx_is_ordered(tmp, continuous.only = TRUE)
#' isContinuous = !umx_is_ordered(tmp)
#' tmp$gear = factor(mtcars$gear) # unordered factor
#' # nb: Factors are not necessarily ordered! By default unordered factors cause an message...
#' \dontrun{
#' tmp$cyl = factor(mtcars$cyl)
#' umx_is_ordered(tmp, names=TRUE)
#' }
umx_is_ordered <- function(df, names = FALSE, strict = TRUE, binary.only = FALSE, ordinal.only = FALSE, continuous.only = FALSE) {
	if(sum(c(binary.only, ordinal.only, continuous.only)) > 1){
		stop("Only one of binary.only ordinal.only and continuous.only can be TRUE")
	}
	if(!is.data.frame(df)){
		if(is.matrix(df)){
			df = data.frame(df)
			# stop("df argument to umx_is_ordered must be a dataframe. You gave me a matrix")
		} else {
			# df = data.frame(df)
			stop("Argument df must be a dataframe. You gave me a ", class(df), ". Perhaps this is one column selected from a data frame without [r,c, drop=FALSE]? ")
		}
	}
	nVar = ncol(df);
	# Which are ordered factors?
	isFactor  = rep(FALSE, nVar)
	isOrdered = rep(FALSE, nVar)
	for(n in 1:nVar) {
		if(is.ordered(df[, n])) {
			thisLevels  = length(levels(df[, n]))
			if(binary.only & (2 == thisLevels) ){
				isOrdered[n] = TRUE
			} else if(ordinal.only & (thisLevels > 2) ){
				isOrdered[n] = TRUE	
			} else if(!binary.only & !ordinal.only) {
				isOrdered[n] = TRUE
			}
		}
		if(is.factor(df[,n])) {
			thisLevels = length(levels(df[,n]))
			if(binary.only & (2 == thisLevels) ){
				isFactor[n] = TRUE
			} else if(ordinal.only & (thisLevels > 2) ){
				isFactor[n] = TRUE	
			} else if(!binary.only & !ordinal.only) {
				isFactor[n] = TRUE
			}
		}
	}
	if(any(isFactor & ! isOrdered) & strict){
		message("Dataframe contains at least 1 unordered factor. Set strict = FALSE to allow this.\n",
			  omxQuotes(names(df)[isFactor & ! isOrdered])
		)
	}

	if(continuous.only){
		isOrdered = !isOrdered
		isFactor  = !isFactor
	}

	if(names){
		if(strict){
			return(names(df)[isOrdered])
		} else {
			return(names(df)[isFactor])
		}
	} else {
		if(strict){
			return(isOrdered)
		} else {
			return(isFactor)
		}
	}
}

#' umx_is_RAM
#'
#' Utility function returning a binary answer to the question "Is this a RAM model?"
#'
#' @param obj an object to be tested to see if it is an OpenMx RAM \code{\link{mxModel}}
#' @return - Boolean
#' @export
#' @family Test
#' @references - \url{https://www.github.com/tbates/umx}
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
#' umxSummary(m1, show = "std")
#' if(umx_is_RAM(m1)){
#' 	message("nice RAM model!")
#' }
#' if(!umx_is_RAM(m1)){
#' 	message("model must be a RAM model")
#' }
umx_is_RAM <- function(obj) {
	# return((class(obj$objective)[1] == "MxRAMObjective" | class(obj$expectation)[1] == "MxExpectationRAM"))
	if(!umx_is_MxModel(obj)){
		return(F)
	} else if(class(obj)[1] == "MxRAMModel"){
		return(T)
	} else {
		return(class(obj$objective)[1] == "MxRAMObjective")
	}
}

#' umx_is_MxModel
#'
#' Utility function returning a binary answer to the question "Is this an OpenMx model?"
#'
#' @param obj An object to be tested to see if it is an OpenMx \code{\link{mxModel}}
#' @param listOK Is it acceptable to pass in a list of models? (Default = FALSE)
#' @return - Boolean
#' @export
#' @family Test
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' m1 = mxModel("test")
#' if(umx_is_MxModel(m1)){
#' 	message("nice OpenMx model!")
#' }
#' if(umx_is_MxModel(list(m1,m1), listOK = TRUE)){
#' 	message("nice list of OpenMx models!")
#' }
umx_is_MxModel <- function(obj, listOK = FALSE) {
	if(is.list(obj)){
		if(!listOK){
			message("If you're expecting a list of models, set listOK = TRUE")
			testVal = FALSE
		}else{
			n = 1
			testVal = TRUE
			for (m in obj) {
				if(!umx_is_MxModel(m, listOK = FALSE)){
					testVal = FALSE
				}
				n = n + 1
			}
		}
	} else {
		testVal = isS4(obj) & is(obj, "MxModel")
	}
	return(testVal)
}

#' umx_is_MxMatrix
#'
#' Utility function returning a binary answer to the question "Is this an OpenMx mxMatrix?"
#'
#' @param obj an object to be tested to see if it is an OpenMx \code{\link{mxMatrix}}
#' @return - Boolean
#' @export
#' @family Test
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' x = mxMatrix(name = "eg", type = "Full", nrow = 3, ncol = 3, values = .3)
#' if(umx_is_MxMatrix(x)){
#' 	message("nice OpenMx matrix!")
#' }
umx_is_MxMatrix <- function(obj) {
	isS4(obj) & is(obj, "MxMatrix")	
}

#' umx_is_cov
#'
#' test if a data frame or matrix is cov or cor data, or is likely to be raw...
#' @param data dataframe to test
#' @param boolean whether to return the type ("cov") or a boolean (default = string)
#' @param verbose How much feedback to give (default = FALSE)
#' @return - "raw", "cor", or "cov", or, if boolean= T, then T | F
#' @export
#' @family Test
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' df = cov(mtcars)
#' umx_is_cov(df)
#' df = cor(mtcars)
#' umx_is_cov(df)
#' umx_is_cov(df, boolean = TRUE)
#' umx_is_cov(mtcars, boolean = TRUE)
umx_is_cov <- function(data = NULL, boolean = FALSE, verbose = FALSE) {
	if(is.null(data)) { stop("Error in umx_is_cov: You have to provide the data = that you want to check...\n",
		"Or as Jack Nicholson says, 'No ticky, no laundry' :-) ") }

	if( nrow(data) == ncol(data)) {
		if(all(data[lower.tri(data)] == t(data)[lower.tri(t(data))])){
			if(all(diag(data) == 1)){
				isCov = "cor"
				if(verbose){
					message("treating data as cor")
				}
			} else {
				isCov = "cov"
				if(verbose){
					message("treating data as cov")
				}
			}
		} else {
			isCov = "raw"
			if(verbose){
				message("treating data as raw: it's a bit odd that it's square, however")
			}
		}
	} else {
		isCov = "raw"
		if(verbose){
			message("treating data as raw")
		}
	}
	if(boolean){
		return(isCov %in%  c("cov", "cor"))
	} else {
		return(isCov)
	}
}

#' umx_has_means
#'
#' A utility function to return a binary answer to the question "does this \code{\link{mxModel}} have a means model?" 
#'
#' @param model The \code{\link{mxModel}} to check for presence of means
#' @return - TRUE or FALSE
#' @export
#' @family Test
#' @references - https://www.github.com/tbates/umx/
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
#' umx_has_means(m1)
#' m1 <- mxModel(m1,
#' 	mxPath(from = "one", to = manifests),
#' 	mxData(demoOneFactor[1:100,], type = "raw")
#' )
#' umx_has_means(m1)
#' m1 = umxRun(m1, setLabels = TRUE, setValues = TRUE)
#' umx_has_means(m1)
umx_has_means <- function(model) {
	if(!umx_is_RAM(model)){
		stop("TODO umx_has_means can only test RAM models so far")
	}
	return(!is.null(model$matrices$M))
}

#' umx_has_CIs
#'
#' A utility function to return a binary answer to the question "does this \code{\link{mxModel}} have confidence intervals?" 
#'
#' @param model The \code{\link{mxModel}} to check for presence of CIs
#' @param check What to check for: "intervals" requested, "output" present, or "both". Defaults to "both"
#' @return - TRUE or FALSE
#' @export
#' @family Test
#' @references - https://www.github.com/tbates/umx/
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
#' umx_has_CIs(m1) # FALSE: no CIs and no output
#' m1 = mxModel(m1, mxCI("G_to_x1"))
#' umx_has_CIs(m1, check = "intervals") # TRUE intervals set
#' umx_has_CIs(m1, check = "output")  # FALSE not yet run
#' m1 = mxRun(m1)
#' umx_has_CIs(m1, check = "output")  # Still FALSE: Set and Run
#' m1 = mxRun(m1, intervals = TRUE)
#' umx_has_CIs(m1, check = "output")  # TRUE: Set, and Run with intervals = T
umx_has_CIs <- function(model, check = c("both", "intervals", "output")) {
	check = umx_default_option(check, c("both", "intervals", "output"), check=F)
	if(is.null(model$intervals)){
		thisModelHasIntervals = FALSE
	}else{
		thisModelHasIntervals = length(names(model$intervals)) > 0
	}
	if(is.null(model$output$confidenceIntervals)){
		thisModelHasOutput = FALSE
	} else {
		thisModelHasOutput = dim(model$output$confidenceIntervals)[1] > 0
	}
	# do logic of returning a value
	if(check == "both"){
		return(thisModelHasIntervals & thisModelHasOutput)
	} else if(check == "intervals"){
		return(thisModelHasIntervals)
	}else{
		return(thisModelHasOutput)
	}
}

#' Check for required features in an OpenMx.
#'
#' Allows the user to straight-forwardly require a specific model type (i.e., 
#' "RAM", "LISREL", etc.), whether or not the model has data, if it has been run or not. 
#' You can also test whether is has a means model or not and (in future) test if it has submodels.
#'
#' @param obj an object to check
#' @param type what type the model must be, i.e., "RAM", "LISREL", etc. (defaults to not checking NULL)
#' @param hasData whether the model should have data or not (defaults to not checking NULL)
#' @param beenRun whether the model has been run or not (defaults to not checking NULL)
#' @param hasMeans whether the model should have a means model or not (defaults to not checking NULL)
#' @param checkSubmodels whether to check submodels (not implemented yet) (default = FALSE)
#' @param callingFn = To help user interprete error, add the name of the calling function.
#' @return - boolean
#' @export
#' @family Test
#' @references - \url{https://www.github.com/tbates/umx}
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
#' umx_check_model(m1)
#' umx_check_model(m1, type = "RAM") # equivalent to umx_is_RAM()
#' umx_check_model(m1, hasData = TRUE)
#' \dontrun{
#' umx_check_model(m1, hasMeans = TRUE)
#' umx_check_model(m1, beenRun = FALSE)
#' }
umx_check_model <- function(obj, type = NULL, hasData = NULL, beenRun = NULL, hasMeans = NULL, checkSubmodels = FALSE, callingFn = "a function") {
	# TODO umx_check_model check hasSubmodels = FALSE
	if (!umx_is_MxModel(obj)) {
		stop("'obj' must be an mxModel")
	}
	if(is.null(type)){
		# No check
	}else if(type == "RAM"){
		if (!umx_is_RAM(obj)) {
			stop(paste0("'obj' must be an RAMModel for use with ", callingFn))
		}
	} else {
		# Assume type is a class string
		if(class(obj)[1] != type){
			stop("You used ", callingFn, " on a model of class ", class(obj)[1], "not ", omxQuotes(type))
		}
	}
	if(checkSubmodels){
		if (length(obj$submodels) > 0) {
			message("Cannot yet handle models with submodels")
		}
	}
	if(!is.null(hasData)){
		if (hasData & is.null(obj$data$observed)) {
			stop("'model' does not contain any data")
		}
	}
	if(!is.null(beenRun)){
		if(!(umx_has_been_run(obj) == beenRun)){
			stop("'model' run state != ", beenRun)		
		}
	}
	if(!is.null(hasMeans)){
		if (!(hasMeans == umx_has_means(obj))) {
			stop("'model' does or does not have means")
		}
	}
	return(TRUE)
}

#' Reorder or drop variables from a correlation/covariance matrix.
#'
#' Reorder the variables in a correlation matrix. Can also remove one or more variables from a matrix using this function.
#'
#' @param old a square matrix of correlation or covariances to reorder
#' @param newOrder Variables you want in the order you wish to have
#' @return - the re-ordered/resized matrix
#' @export
#' @family Data Functions
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' oldMatrix = cov(mtcars)
#' umx_reorder(oldMatrix, newOrder = c("mpg", "cyl", "disp")) # first 3
#' umx_reorder(oldMatrix, newOrder = c("hp", "disp", "cyl")) # subset and reordered
#' umx_reorder(oldMatrix, "hp") # edge-case of just 1-var
umx_reorder <- function(old, newOrder) {
	if(!umx_is_cov(old, boolean = TRUE)){
		stop("You don't appear to have offered up a covariance matrix.")
	}
	dim_names = dimnames(old)[[1]]
	if(!all(newOrder %in% dim_names)){
		stop("All variable names must appear in the matrix being umx_reorder'd")
	}
	numVarsToRetain = length(newOrder)
	new = old[1:numVarsToRetain, 1:numVarsToRetain, drop = FALSE]
	dimnames(new) = list(newOrder, newOrder)
	for(r in newOrder) {
		for(c in newOrder) {
			new[r, c] <- old[r, c]
		}
	}
	return(new)
}

#' umx_cont_2_quantiles
#'
#' Recode a continuous variable into n-quantiles (default = deciles (10 levels)).
#' It returns an \code{\link{mxFactor}}, with the levels labeled with the max value
#' in each quantile (i.e., open on the left-side). quantiles are labeled "quantile1"
#' "quantile2" etc.
#' 
#' \strong{Note}: Redundant quantiles are merged. i.e., if the same score identifies
#' all deciles up to the fourth, then these will be merged into one bin, labeled "quantile4".
#'
#' @aliases umx2ord
#' @param x a variable to recode as ordinal (email me if you'd like this upgraded to handle df input)
#' @param nlevels How many bins or levels (at most) to use (i.e., 10 = deciles)
#' @param type what to return (Default is "mxFactor") options: "ordered" and "unordered")
#' @param verbose report the min, max, and decile cuts used (default = FALSE)
#' @param returnCutpoints just return the cutpoints, for use directly
#' @return - recoded variable as an \code{\link{mxFactor}}
#' @export
#' @family Miscellaneous Utility Functions
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' x = umx_cont_2_quantiles(rnorm(1000), nlevels = 10, verbose = TRUE)
#' x = data.frame(x)
#' str(x); levels(x)
#' table(x)
#' \dontrun{
#' ggplot2::qplot(x$x)
#' y = mxDataWLS(x, type = "WLS")
#' }
#' 
#'# ===========================
#'# = Use with twin variables =
#'# ===========================
#' 
#' data(twinData)
#' x = twinData
#' cuts  = umx_cont_2_quantiles(rbind(x$wt1, x$wt2) , nlevels = 10, returnCutpoints = TRUE)
#' x$wt1 = umx_cont_2_quantiles(x$wt1, nlevels = cuts) # use same for both...
#' x$wt2 = umx_cont_2_quantiles(x$wt2, nlevels = cuts) # use same for both...
#' str(x[, c("wt1", "wt2")])
#' 
#' # More examples
#' 
#' x = umx_cont_2_quantiles(mtcars[, "mpg"], nlevels = 5) # quintiles
#' x = umx2ord(mtcars[, "mpg"], nlevels = 5) # using shorter alias
#' x = umx_cont_2_quantiles(mtcars[, "cyl"], nlevels = 10) # more levels than integers exist
#' x = umx_cont_2_quantiles(rbinom(10000, 1, .5), nlevels = 2)
umx_cont_2_quantiles <- function(x, nlevels = NULL, type = c("mxFactor", "ordered", "unordered"), verbose = FALSE, returnCutpoints = FALSE){
	# TODO: umx_cont_2_quantiles: Check if is.data.frame(x) && dim(x)[2] > 1, and if so, proceed column-wise
	type = match.arg(type)
	if(is.data.frame(x) && dim(x)[2] > 1){
		stop("I can only handle single vectors: email tim and rip him a new one")
	}
	if(!is.numeric(x) ){
		stop("This is for numeric variables. you gave me a ", typeof(x))
	}

	if(is.null(nlevels)){
		stop("You must set the number of levels, i.e., 'nlevels = 10'  to threshold data into deciles")
	} else if(length(nlevels) > 1){
		# Levels contains a list of cutpoints
		cutPoints = nlevels
		nlevels   = length(cutPoints) + 1
		levelLabels = paste0("quantile", 1:(nlevels))
	} else {
		cutPoints = quantile(x, probs = c((1:(nlevels-1)) / (nlevels)), type = 8, na.rm = TRUE)
		levelLabels = paste0("quantile", 1:(nlevels))
		## needed to collapse overlapping quantiles
		uniqueItems = !duplicated(cutPoints)
		cutPoints   = cutPoints[uniqueItems]
		levelLabels = levelLabels[uniqueItems]

		# (happens with highly skewed data).
		if(returnCutpoints){
			return(cutPoints)
		}
	}
	cutPoints   = c(-Inf, cutPoints, Inf)
	if(type == "mxFactor"){
		out = cut(x, breaks = cutPoints, labels = levelLabels, ordered_result = TRUE); 
		out = mxFactor(out, levels = levels(out))
	} else if (type == "ordered") {
		out = cut(x, breaks = cutPoints, labels = levelLabels, ordered_result = TRUE); 		
	} else {
		out = cut(x, breaks = cutPoints, labels = levelLabels); 
	}
	if(verbose){
		message("Scores ranged from ", min(x), " to ", max(x), ". Cuts made at ", omxQuotes(cutPoints))
	}
	return(out)
}

#' @export
umx2ord <- umx_cont_2_quantiles

#' Check if a label contains square brackets
#'
#' Helper function to check if a label has square brackets, e.g. "A[1,1]"
#'
#' @param input The label to check for square brackets (string input)
#' @return - boolean
#' @export
#' @family Test
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' umx_has_square_brackets("[hello]")
#' umx_has_square_brackets("goodbye")
umx_has_square_brackets <- function (input) {
    match1 <- grep("[", input, fixed = TRUE)
    match2 <- grep("]", input, fixed = TRUE)
    return(length(match1) > 0 && length(match2) > 0)
}


#' Convert a string to an OpenMx algebra
#'
#' This is useful use to quickly and easily insert values from R variables into the string (using paste() and rep() etc.), then parse the string as an mxAlgebra argument.
#' A use case is including a matrix exponent (that is A %*% A %*% A %*% A...) with a variable exponent. 
#'
#' @param algString a string to turn into an algebra
#' @param name of the returned algebra
#' @param dimnames of the returned algebra
#' @return - \code{\link{mxAlgebra}}
#' @export
#' @family Advanced Model Building Functions
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' \dontrun{
#' alg = umx_string_to_algebra(paste(rep("A", nReps), collapse = " %*% "), name = "test_case")
#' }
umx_string_to_algebra <- function(algString, name = NA, dimnames = NA) {
	eval(substitute(mxAlgebra(tExp, name=name, dimnames=dimnames), list(tExp = parse(text=algString)[[1]])))
}

#' umx_object_as_str
#'
#' Utility to return an object's name as a string
#'
#' @param x an object
#' @return - name as string
#' @export
#' @family String Functions
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' umx_object_as_str(mtcars) # "mtcars"
umx_object_as_str<- function(x) {
  deparse(substitute(x))
}

#' umxEval
#'
#' Takes an expression as a string, and evaluates it as an expression in model, optionally computing the result.
#' # TODO umxEval Currently broken... delete submit as update to OpenMx?
#'
#' @param expstring an expression string, i.e, "a + b"
#' @param model an \code{\link{mxModel}} to evaluate in
#' @param compute Whether to compute the result or not (default = FALSE)
#' @param show Whether to show??? (default = FALSE)
#' @return - an openmx algebra (formula)
#' @export
#' @family Reporting Functions
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' m1 = mxModel("fit",
#'		mxMatrix("Full", nrow = 1, ncol = 1, free = TRUE, values = 1, name = "a"), 
#'		mxMatrix("Full", nrow = 1, ncol = 1, free = TRUE, values = 2, name = "b"), 
#'		mxAlgebra(a %*% b, name = "ab"), 
#'		mxConstraint(ab == 35, name = "maxHours"), 
#'		mxAlgebraObjective(algebra = "ab", numObs= NA, numStats = NA)
#'	)
#' m1 = mxRun(m1)
#' mxEval(list(ab = ab), m1)
umxEval <- function(expstring, model, compute = FALSE, show = FALSE) {
	return(eval(substitute(mxEval(x, model, compute, show), list(x = parse(text=expstring)[[1]]))))
}

#' Scale data columns, skipping non-scalable columns
#'
#' umx_scale applies scale to a data.frame. It scale numeric columns, and is smart enough
#' to skip non-scalable columns (string, factor, etc.).
#'
#' Also strips-off the attributes which scale adds ("scaled:center" and 
#' "scaled:scale" (set attr= TRUE) to keep these.
#'
#' @param df A dataframe to scale (or a numeric vector)
#' @param varsToScale (leave blank to scale all)
#' @param coerce Whether to coerce non-numerics to numeric (Defaults to FALSE.
#' @param verbose Whether to report which columns were scaled (default FALSE)
#' @param attr to strip off the attributes scale creates (FALSE by default)
#' @return - new dataframe with scaled variables
#' @export
#' @seealso umx_scale_wide_twin_data
#' @family Miscellaneous Utility Functions
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' data(twinData) 
#' df = umx_scale(twinData, varsToScale = c("wt1", "wt2"))
#' df = umx_scale(twinData,  attr= TRUE)
#' plot(wt1 ~ wt2, data = df)
umx_scale <- function(df, varsToScale = NULL, coerce = FALSE, attr = FALSE, verbose = FALSE){
	if(!is.data.frame(df)){
		if(is.numeric(df)){
			df = scale(df)[,1]
		}else{
			msg = paste0(quote(df), " isn't a dataframe, it's a", class(df))
			stop(paste0("umx_scale takes a dataframe (or numeric vector) as its first argument.", msg))
		}
	}else{
		# For each column, if numeric, scale
		if(is.null(varsToScale)){
			varsToScale = names(df)
		}
		if(coerce){
			df[, varsToScale] = umx_as_numeric(df[, varsToScale])
		}
		varsToScale = varsToScale[umx_is_numeric(df[,varsToScale], all = FALSE)]
		if(verbose){
			message("Vars I will scale are:", omxQuotes(varsToScale))
			
			message("Vars I will leave alone are:", omxQuotes(setdiff(names(df), varsToScale)))
		}
		if(length(varsToScale)==1){
			df[ ,varsToScale] = scale(df[ ,varsToScale])[,1, drop=T]
		} else {
			df[ ,varsToScale] = scale(df[ ,varsToScale])
		}
	}
	if(!attr){
		attr(df, which = "scaled:center") = NULL
		attr(df, which = "scaled:scale")  = NULL
	}
	return(df)
}

#' Check if variables in a dataframe are in a list of classes.
#'
#' @description
#' Checks the class of each column in a dataframe, seeing if they are %in% a list of classes.
#' Returns a vector of TRUE and FALSE, or, if all ==TRUE, a single binary (the default).
#'
#' @param df A dataframe to check
#' @param classes vector of valid classes, e.g. numeric
#' @param all Whether to return a single all() Boolean or each column individually.
#' @return - Boolean or Boolean vector
#' @export
#' @family Check or test
#' @seealso - \code{\link{umx_is_numeric}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' umx_is_class(mtcars) # report class list
#' # Are the variables in mtcars type character?
#' umx_is_class(mtcars, "character") # FALSE
#' # They're all numeric data
#' umx_is_class(mtcars, "numeric") # TRUE
#' # Show the test-result for each variable in mtcars
#' umx_is_class(mtcars, "numeric") # TRUE
#' # Are they _either_ a char OR a num?
#' umx_is_class(mtcars, c("character", "numeric"))
#' # Is zygosity a factor (note we don't drop = F to keep as dataframe)
#' umx_is_class(twinData[,"zygosity", drop=FALSE], classes = "factor")
umx_is_class <- function(df, classes=NULL, all = TRUE){
	if(!is.data.frame(df)){
		if(is.null(classes)){
			return(class(df))		
		}else{
			return(class(df %in% classes))
		}
	}
	colNames = names(df)
	bIsOK = rep(FALSE, length(colNames))
	i = 1
	if(is.null(classes)){
		for (n in colNames) {
			bIsOK[i] = class(df[, n])[1]
			i = i + 1
		}
		return(bIsOK)
	}else{
		bIsOK = rep(FALSE, length(colNames))
		for (n in colNames) {
			bIsOK[i] = (class(df[, n]) %in% classes)[1]
			i = i + 1
		}
		if(all){
			return(all(bIsOK))
		} else {
			return(bIsOK)
		}
	}
}

#' Check if variables in a dataframe are numeric
#'
#' @description
#' Checks across columns of a dataframe, return a vector of TRUE and FALSE, 
#' or, if all ==TRUE, a single binary (the default).
#'
#' @param df A dataframe to check
#' @param all Whether to return a single all() Boolean or each column individually.
#' @return - Boolean or Boolean vector
#' @export
#' @family Check or test
#' @seealso - \code{\link{umx_is_class}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' umx_is_numeric(mtcars) # TRUE
#' umx_is_numeric(mtcars, all=FALSE) # vector of TRUE
umx_is_numeric <- function(df, all = TRUE){
	if(!is.data.frame(df)){
		stop(paste0("First argument should be a dataframe as its first argument. ", quote(df), " isn't a dataframe"))
	}
	colNames = names(df)
	bIsNumeric = rep(FALSE, length(colNames))
	i = 1
	for (n in colNames) {
		bIsNumeric[i] = is.numeric(df[,n])
		i = i + 1
	}
	if(all){
		return(all(bIsNumeric))
	} else {
		return(bIsNumeric)
	}
}

#' Easily residualize variables in long or wide dataframes, returning them changed in-place.
#'
#' @description Residualize one or more variables residualized against covariates, and return a
#' complete dataframe with residualized variable in place.
#' Optionally, this also works on wide (i.e., twin) data. Just supply suffixes to identify
#' the paired-wide columns (see examples).
#' 
#' @details In R, residuals for a variable can be found with the following statement:
#' 
#' \code{tmp <- residuals(lm(var ~ cov1 + cov2, data = data, na.action = na.exclude))}
#'
#' This tmp variable could then be written over the old data:
#' 
#' umx_residualize obviates the user having to build the lm, set na.action, or replace the data.
#' In addition, it has the powerful feature of operating on a list of variables, and of operating on
#' wide data, expanding the var name using a set of variable-name suffixes.
#' 
#' @param var The base name of the variable you want to residualize. Alternatively, a 
#' regression \code{\link{formula}} containing var on the lhs, and covs on the rhs
#' @param covs Covariates to residualize on.
#' @param suffixes Suffixes that identify the variable for each twin, i.e. c("_T1", "_T2")
#' Up to you to check all variables are present!
#' @param data The dataframe containing all the variables
#' @return - dataframe with var residualized in place (i.e under its original column name)
#' @export
#' @family Twin Data functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' # Residualize mpg on cylinders and displacement
#' r1 = umx_residualize("mpg", c("cyl", "disp"), data = mtcars)
#' r2 = residuals(lm(mpg ~ cyl + disp, data = mtcars, na.action = na.exclude))
#' all(r1$mpg == r2)
#' # =====================
#' # = formula interface =
#' # =====================
#' r1 = umx_residualize(mpg ~ cyl + I(cyl^2) + disp, data = mtcars)
#' r2 = residuals(lm(mpg ~ cyl + I(cyl^2) + disp, data = mtcars, na.action = na.exclude))
#' all(r1$mpg == r2)
#' 
#' # ========================================================================
#' # = Demonstrate ability to residualize WIDE data (i.e. 1 family per row) =
#' # ========================================================================
#' tmp = mtcars
#' tmp$mpg_T1  = tmp$mpg_T2  = tmp$mpg
#' tmp$cyl_T1  = tmp$cyl_T2  = tmp$cyl
#' tmp$disp_T1 = tmp$disp_T2 = tmp$disp
#' umx_residualize("mpg", c("cyl", "disp"), c("_T1", "_T2"), data = tmp)[1:5,12:17]
#' 
#' # ===================================
#' # = Residualize several DVs at once =
#' # ===================================
#' df1 = umx_residualize(c("mpg", "hp"), cov = c("cyl", "disp"), data = tmp)
#' df2 = residuals(lm(hp ~ cyl + disp, data = tmp, na.action = na.exclude))
#' all(df1$hp == df2)
umx_residualize <- function(var, covs = NULL, suffixes = NULL, data){
	# Check names	
	nVar = length(var)
	if(nVar > 1 && class(var) != "formula"){
		for (i in 1:nVar) {
			data = umx_residualize(var[i], covs = covs, suffixes = suffixes, data = data)
		}
		return(data)
	} else {
		if(class(var) == "formula"){
			umx_check(is.null(covs), "stop", "when using formula, leave covs empty")
			form <- var
			var  = all.vars(terms(form))[1]
			covs = all.vars(delete.response(terms(form)))
		} else {
			form = NULL # so we catch this and create it below
		}
	
		if(is.null(suffixes)){
			vars = c(var, covs)
		} else {
			# Wide vars provided: expand names
			vars = umx_paste_names(c(var, covs), suffixes = suffixes)
		}
		umx_check_names(vars, data = data, die = TRUE)
		nVar = length(c(var, covs))

		if(!is.null(suffixes)){
			# Make a long version of the vars we want
			for (i in 1:length(suffixes)) {
				vars = umx_paste_names(c(var, covs), suffixes = suffixes[i])
				if(i == 1){
					tmp = data[,vars]
					names(tmp) = c(var, covs)
				} else {
					tmp2 = data[,vars]
					names(tmp2) = c(var, covs)
					tmp = rbind(tmp, tmp2)
				}
			}
		} else {
			tmp = data[,vars]
		}
		oldNAs = sum(is.na(tmp[,var]))
		# If formula not provided, construct it from var and covs
		if(is.null(form)){
			form = paste0(var, " ~ ", paste(covs, collapse = " + "))
			form = as.formula(form)
		}
		tmp <- residuals(lm(form, data = tmp, na.action = na.exclude))
		newNAs = sum(is.na(tmp))
		if(newNAs > oldNAs){
			message(newNAs - oldNAs, " cases of var ", omxQuotes(var), "lost due to missing covariates")
		}
		if(!is.null(suffixes)){
			i = 1
			nRows = nrow(data)
			for (suff in suffixes) {
				data[, paste0(var, suff)] = tmp[i:(i+nRows-1)]
				i = i + nRows
			}
		} else {
			data[, var] = tmp
		}
		return(data)
	}
}

#' umx_scale_wide_twin_data
#'
#' Scale wide data across all cases: currently 2 twins.
#'
#' @param varsToScale The base names of the variables ("weight" etc.)
#' @param sep The suffix that distinguishes each case, e.g. "_T")
#' @param data a wide dataframe
#' @param suffix  (deprecated: use sep instead)
#' @return - new dataframe with variables scaled in place
#' @export
#' @seealso umx_scale
#' @family Twin Data functions
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' data(twinData) 
#' df = umx_scale_wide_twin_data(data = twinData, varsToScale = c("ht", "wt"), sep = "" )
#' plot(wt1 ~ wt2, data = df)
umx_scale_wide_twin_data <- function(varsToScale, sep, data, suffix = "deprecated") {
	if(suffix != "deprecated"){
		message("Hi! Next time, use sep instead of suffix, when calling umx_scale_wide_twin_data")
		sep = suffix
	}
	if(length(sep) != 1){
		stop("I need one sep, you gave me ", length(sep), "\nYou, might, for instance, need to change c('_T1', '_T2') to just '_T'")
	}
	# TODO discover suffixes as unique digits following suffix (could be 1:6)
	namesNeeded = umx_paste_names(varsToScale, sep = sep, suffixes = 1:2)
	umx_check_names(namesNeeded, data)
	t1Traits = paste0(varsToScale, sep, 1)
	t2Traits = paste0(varsToScale, sep, 2)
	for (i in 1:length(varsToScale)) {
		T1 = data[,t1Traits[i]]
		T2 = data[,t2Traits[i]]
		totalMean = mean(c(T1, T2), na.rm = TRUE)
		totalSD   =   sd(c(T1, T2), na.rm = TRUE)
		T1 = (T1 - totalMean)/totalSD
		T2 = (T2 - totalMean)/totalSD
		data[,t1Traits[i] ] = T1
		data[,t2Traits[i] ] = T2
	}
	return(data)
}

#' Select first item in list of options, while being flexible about choices.
#'
#' Like a smart version of \code{\link{match.arg}}: Handles selecting parameter options when default is a list.
#' Unlike  x = \code{\link{match.arg}}(x) this allows items not in the list.
#'
#' @aliases umx_match.arg
#' @param x the value chosen (may be the default option list)
#' @param option_list  A vector of valid options
#' @param check Whether to check that single items are in the list. Set false to accept abbreviations (defaults to TRUE) 
#' @return - one validated option
#' @export
#' @family Get and set
#' @seealso - \code{\link{match.arg}}
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' option_list = c("default", "par.observed", "empirical")
#' umx_default_option("par.observed", option_list)
#' 
#' # An example of checking a bad item and stopping
#' \dontrun{
#' umx_default_option("bad", option_list)
#' }
#' umx_default_option("allow me", option_list, check = FALSE)
#' umx_default_option(option_list, option_list)
#' option_list = c(NULL, "par.observed", "empirical")
#'  # fails with NULL!!!!!
#' umx_default_option(option_list, option_list)
#' option_list = c(NA, "par.observed", "empirical")
#' umx_default_option(option_list, option_list) # use NA instead
#' option_list = c(TRUE, FALSE, NA)
#' umx_default_option(option_list, option_list) # works with non character
umx_default_option <- function(x, option_list, check = TRUE){
	# Often Rs match.arg  will work...
	# filter = match.arg(filter)
	if (identical(x, option_list)) {
	    x = option_list[1]
			return(x)
	}else{
		if(check){
			if((x %in% option_list)) {
				return(x)
			} else {
				stop(paste("argument must be one of ", paste(sQuote(option_list), collapse = ", ")))
			}
		} else {
			# don't check
			return(x)
		}
	}
}

#' @export
umx_match.arg <- umx_default_option


#' qm
#'
#' Quickmatrix function
#'
#' @param ... the components of your matrix
#' @param rowMarker mark the end of each row
#' @return - matrix
#' @family Miscellaneous Utility Functions
#' @references \url{http://www.sumsar.net/blog/2014/03/a-hack-to-create-matrices-in-R-matlab-style}
#' @export
#' @examples
#' # simple example
#' qm(0, 1 |
#'    2, NA)
#' \dontrun{
#' # clever example
#' M1 = M2 = diag(2)
#' qm(M1,c(4,5) | c(1,2),M2 | t(1:3))
#' }
qm <- function(..., rowMarker = "|") {
	# Short hard to read version that allows some of the more advanced Matlab capabilities like Matrices as arguments:
	# turn ... into string
	args<-deparse(substitute(rbind(cbind(...))))
	# create "rbind(cbind(.),cbind(.),.)" construct
	sep = paste0("\\", rowMarker)
	args<-gsub(sep, "), cbind(", args)
	# eval
	eval(parse(text = args))
}

# easier to read variant that does not accept matrices as arguments...
# qm <- function(..., colsep = "|") {
# 	# Get the arguments as a list
# 	arg <- eval(substitute(alist(...)))
# 	out <- strsplit(as.character(arg), split = colsep, fixed = TRUE)
# 	ns <- sapply(out, length)
# 	ncol <- if(any(ns > 1)){min(which(ns>1))}else{length(ns)}
# 	matrix(as.numeric(unlist(out)), ncol = ncol, byrow = TRUE)
# }

#  tic()
# 
#  toc()
# 
# tic <- function(gcFirst = TRUE, type=c("elapsed", "user.self", "sys.self")){
#    type <- match.arg(type)
#    assign(".type", type, envir=baseenv())
#    if(gcFirst) gc(FALSE)
#    tic <- proc.time()[type]         
#    assign(".tic", tic, envir=baseenv())
#    invisible(tic)
# }
# 
# toc <- function(){
#    type <- get(".type", envir=baseenv())
#    toc <- proc.time()[type]
#    tic <- get(".tic", envir=baseenv())
#    print(toc - tic)
#    invisible(toc)
# }
# 
# library(rbenchmark)
# # Example 1
# # Benchmarking the allocation of one 10^6-element numeric vector,
# # by default replicated 100 times
# benchmark(1:10^6)
# # simple test functions used in subsequent examples
# random.array <- function(rows, cols, dist=rnorm)
# array(dist(rows*cols), c(rows, cols))
# random.replicate <- function(rows, cols, dist=rnorm)
# replicate(cols, dist(rows))
# 
# library("microbenchmark")
# library("ggplot2")
# tm <- microbenchmark(
# 	rchisq(100, 0),
# 	rchisq(100, 1),
# 	rchisq(100, 2),
# 	rchisq(100, 3),
# 	rchisq(100, 5), times=1000
# )
# boxplot(tm)
# autoplot(tm)
# summary(tm)
# tm <- microbenchmark(1:10^6); autoplot(tm)

# ================================
# = string and php-style helpers =
# ================================
#' umx_explode - like the php function `explode` 
#'
#' Takes a string and returns an array of delimited strings (by default, each character)
#'
#' @param delimiter what to break the string on. Default is empty string ""
#' @param string an character string, e.g. "dog"
#' @return - a vector of strings, e.g. c("d", "o", "g")
#' @export
#' @family String Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}, \url{http://php.net/manual/en/function.explode.php}
#' @examples
#' umx_explode("", "dog") # "d" "o" "g"
#' umx_explode(" ", "cats and dogs") # [1] "cats" "and"  "dogs"
umx_explode <- function(delimiter = character(), string) { 
	strsplit(string, split = delimiter)[[1]] 
}

#' umx_names
#'
#' @description 
#' Convenient equivalent of running [grep] on [names], with value = TRUE and ignore.case = TRUE.
#' 
#' **Plus**:`umx_names` can handle dataframes, a model, list of models, model summary, or a vector of strings as input. 
#' 
#' In these cases, it will search column names, parameter or summary output names, or 
#' the literal string values themselves respectively.
#' 
#' In addition, `umx_names` can do [replacement][grep] of a found string (see exmples). It can also collapse the result (using [paste0])
#' 
#' *Note*: `namez` (with a z) is a shortcut for `umx_names`, which makes it easy to replace where you'd otherwise use [names].
#' 
#' You can learn more about the matching options (like inverting the selection etc.) in the help for base-R [grep].
#'
#' @aliases namez
#' @param df dataframe (or other objects, or a list of models) from which to get names.
#' @param pattern Used to find only matching names (supports grep/regular expressions)
#' @param replacement If not NULL, replaces the found string. Use backreferences ("\1" to "\9") to refer to (subexpressions).
#' @param ignore.case default = TRUE (opposite default to grep)
#' @param perl Should Perl-compatible regexps be used? Default = FALSE
#' @param value Return matching elements themselves (TRUE) or their indices (FALSE) default = TRUE (opposite default to grep)
#' @param fixed = FALSE (grep option If TRUE, pattern is a string to be matched as is. Overrides all conflicting arguments.)
#' @param useBytes = FALSE logical. grep option. If TRUE, matching is by byte rather than by character.
#' @param invert Return indices or values for elements that do not match (default = FALSE).
#' @param global replace all instances in each strong, or just the first (Default).
#' @param collapse "as.is" leaves alone. as.vector formats as pastable code, i.e., "c('a', 'b')", not "a"  "b" (default NULL), etc.
#' @return - vector of matches
#' @export
#' @seealso - Base-R pattern matching functions: \code{\link{grep}}.
#' And \code{\link{umx_check_names}} to check for existence of names in a dataframe. 
#' @family Reporting Functions
#' @family String Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @md
#' @examples
#' # Names from a dataframe, with character matching
#' umx_names(mtcars, "mpg") # only "mpg" matches this
#' 
#' # Easy-to-type alias "namez"
#' namez(mtcars, "mpg")
#' 
#' # Use a regular expression to match a pattern
#' namez(mtcars, "r[ab]") # "drat", "carb"
#' namez(mtcars, "^d") # vars beginning with 'd' = "disp", drat
#' 
#' # Use this function to replace text in names!
#' umx_names(mtcars, "mpg", replacement = "hello") # "mpg" replaced with "hello"
#' 
#' 
#' # ========================================================================
#' # = Using the custom collapse option to quote each item, and wrap in c() =
#' # ========================================================================
#' namez(mtcars, "m", collapse = "as.vector") # Paste-able R-code for a vector
#' 
#' # Other options passed to R's grep command
#' umx_names(mtcars, "mpg" , invert = TRUE)  # Non-matches (instead of matches)
#' umx_names(mtcars, "disp", value  = FALSE) # Return indices of matches 
#' umx_names(mtcars, "^d"  , fixed  = TRUE)  # Vars containing literal '^d' (none...)
#' 
#' # =======================================
#' # = Examples using built-in GFF dataset =
#' # =======================================
#'
#' # Just show phenotypes for Twin 1
#' umx_names(GFF, "T_1$") # twin 1
#' # "zyg" "sex1" "age_T1" "gff_T1" "fc_T1" "qol_T1" "hap_T1"...
#' 
#' umx_names(GFF, "2$") # names ending in 2
#' umx_names(GFF, "[^12bs]$") # doesn't end in `1`, `2`, `b`, or `s`
#' # "zyg_6grp" "zyg_2grp" "divorce"
#' umx_names(mxData(twinData[, c("wt1", "wt2")], type= "raw"))
#' umx_names(mxData(cov(twinData[, c("wt1", "wt2")], use="comp"), type= "cov", numObs= 1000))
#' umx_names(mxDataWLS(na.omit(twinData[, c("wt1", "wt2")]), type= "WLS"))
umx_names <- function(df, pattern = ".*", replacement = NULL, ignore.case = TRUE, perl = FALSE, value = TRUE, fixed = FALSE, useBytes = FALSE, invert = FALSE, global = FALSE, collapse = c("as.is", "as.vector", "as.formula")) {
	collapse = match.arg(collapse)
	if(fixed){
		ignore.case = FALSE
	}
	if(class(df) %in%  c("summary.mxmodel", "data.frame")){
		nameVector = names(df)
	}else if(class(df)[1] %in% c("MxNonNullData", "MxDataStatic") ) {
			if(df$type == "raw"){
				nameVector = names(df$observed)
				isRaw = TRUE
			} else {
				nameVector = colnames(df$observed)
				isRaw = FALSE
			}
			if(is.null(nameVector)){
				stop("There's something wrong with the mxData - I couldn't get the variable names from it. Did you set type correctly?")
			}
	} else if(class(df) == "list"){
		# Assume it's a list of mxModels and we want the MODEL names (not parameters... see below)
		nameVector = c()
		for (i in df) {
				nameVector = c(nameVector, i$name)
		}
	} else if(class(df) == "character"){
		nameVector = df
	} else {
		# Assume it's one model, and we want the parameter names
		nameVector = parameters(df)
	}
	if(is.null(nameVector)){
		stop(paste0("umx_names requires a dataframe or something else with names() or parameters(), ", umx_object_as_str(df), " is a ", typeof(df)))
	}
	if(is.null(replacement)){
		tmp =  grep(pattern = pattern, x = nameVector, ignore.case = ignore.case, perl = perl, value = value,
	     fixed = fixed, useBytes = useBytes, invert = invert)
	} else {
		if(global){
			tmp = gsub(pattern = pattern, replacement = replacement, x = nameVector, ignore.case = ignore.case, perl = perl, fixed = fixed, useBytes = useBytes)
		} else {
			tmp = sub(pattern = pattern, replacement = replacement, x = nameVector, ignore.case = ignore.case, perl = perl, fixed = fixed, useBytes = useBytes)
		}
	}
	if(collapse == "as.is"){
		tmp
	}else if(collapse == "as.vector"){
		tmp = paste(tmp, collapse  = "', '")
		paste0("c('", tmp, "')")
	}else if(collapse == "as.formula"){
		tmp = paste(tmp, collapse  = " + ")
		paste0("~ ", tmp)
	} else {
		paste(tmp, collapse  = collapse)
	}
}

#' @export
namez <- umx_names

#' Trim whitespace surrounding a string.
#'
#' Returns string w/o leading or trailing whitespace
#'
#' @param string to trim
#' @param removeThis if not NULL then this string is removed wherever found in 'string'
#' @return - string
#' @export
#' @family String Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' umx_trim(" dog") # "dog"
#' umx_trim("dog ") # "dog"
#' umx_trim("\t dog \n") # "dog"
#' umx_trim("xlsx dog.xlsx", "\\.xlsx$") # "dog"
umx_trim <- function(string, removeThis = NULL) {
	if(is.null(removeThis)){
		# https://www.php.net/manual/en/function.trim.php
		return(gsub("^\\s+|\\s+$", "", string))
		# returns string w/o leading whitespace
		# trim.leading <- function (x)  sub("^\\s+", "", x)
		# returns string w/o trailing whitespace
		# sub("\\s+$", "", x)
	} else {
		return(gsub(removeThis, "", string))
	}
}

#' umx_rot
#'
#' rotate a vector (default, rotate by 1)
#'
#' @param vec vector to rotate
#' @return - \code{\link{mxModel}}
#' @export
#' @family String Functions
#' @references - \url{https://tbates.github.io}
#' @examples
#' umx_rot(1:10)
#' umx_rot(c(3,4,5,6,7))
#' # [1] 4 5 6 7 3
umx_rot <- function(vec){
	ind = (1:length(vec) %% length(vec)) + 1
	vec[ind]
} 


# =================================
# = Data: Read, Prep, Clean, Fake =
# =================================
#' Take a long twin-data file and make it wide (one family per row)
#'
#' @description
#' `umx_long2wide` merges on `famID`. Family members are ordered by `twinID`.
#' 
#' twinID is equivalent to birthorder. Up to 10 twinIDs are allowed (family order).
#' 
#' *Note*: Not all data sets have an order column, but it is essential to rank subjects correctly.
#' 
#' *Note*: The functions assumes that if zygosity or any passalong variables are NA in the first
#' family member, they are NA everywhere. i.e., it does not hunt for values that
#' are present elsewhere to try and self-heal missing data.
#'
#' @param data The original (long-format) data file
#' @param famID  The unique identifier for members of a family
#' @param twinID The twinID. Typically 1, 2, 50 51, etc...
#' @param zygosity Typically MZFF, DZFF MZMM, DZMM DZOS
#' @param vars2keep = The variables you wish to analyse (these will be renamed with paste0("_T", twinID)
#' @param passalong = Variables you wish to pass-through (keep, even though not twin vars)
#' @return - dataframe in wide format
#' @export
#' @family Twin Data functions
#' @seealso - \code{\link{merge}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @md
#' @examples
#' # ================================================================
#' # = First we have to make a long format file to base the demo on =
#' # ================================================================
# # 1. Drop the 'age' column (we have age1 and age2, and age won't make sense in a long format
#' tmp = twinData[, -2]
# # 2. Add fake twinID identifiers for each twin, else this data set won't have a twinID!
#' tmp$twinID1 = 1
#' tmp$twinID2 = 2
#' long = umx_wide2long(data = tmp, sep = "")
#' #
#' 
#' # OK. Now to demo long2wide...
#' 
#' # Keeping all columns
#' wide = umx_long2wide(data= long, famID= "fam", twinID= "twinID", zygosity= "zygosity")
#' names(wide) # some vars, like part, should have been passed along instead of made into "part_T1"
#' 
#' # Just keep bmi and wt
#' wide = umx_long2wide(data= long, famID= "fam", twinID= "twinID", 
#'     zygosity= "zygosity", vars2keep = c("bmi", "wt"))
#' names(wide)
#' 
#' # "fam" "twinID" "zygosity" "bmi_T1" "wt_T1" "bmi_T2" "wt_T2"
#' 
#' # Keep bmi and wt, and pass through 'cohort'
#' wide = umx_long2wide(data= long, famID= "fam", twinID= "twinID", zygosity= "zygosity", 
#'   vars2keep = c("bmi", "wt"), passalong = "cohort")
umx_long2wide <- function(data, famID = NA, twinID = NA, zygosity = NA, vars2keep = NA, passalong = NA) {
	IDVars = c(famID, twinID, zygosity)
	umx_check_names(IDVars, data = data, die = TRUE)

	if(!anyNA(passalong)){
		umx_check_names(passalong, data = data, die = TRUE)
	}

	if(typeof(vars2keep) == "character"){
		# Check user provided list
		umx_check_names(vars2keep, data = data, die = TRUE)
	} else {
		# vars that are not ID columns
		# message("Keeping all variables")
		vars2keep = setdiff(names(data), IDVars)
	}
	
	levelsOfTwinID = unique(data[,twinID])
	if(length(levelsOfTwinID)>10){
		stop("Found ", length(levelsOfTwinID), " levels of twinID. That seems too many??? should be c(1,2,50,51) or similar?")
	} else {
		message("Found ", length(levelsOfTwinID), " levels of twinID: ", omxQuotes(levelsOfTwinID))
	}

	if(NA %in% levelsOfTwinID){
	  message("Some subjects have NA as twinID!")
	}
	# levelsOfTwinID = c(1,2,50,51)

	if(anyNA(passalong)){
		allVars = c(IDVars, vars2keep)		
	}else{
		allVars = c(IDVars, passalong, vars2keep)
	}
	famIDPlus_vars2keep = c(famID, vars2keep)

	# ==================================
	# = Merge each twinID to the right =
	# ==================================
	# Extract all the twins of twinID i, merge by famid with existing blocks 
	for(i in seq_along(levelsOfTwinID)) {
		newNames = paste0(vars2keep, "_T", levelsOfTwinID[i])
		if(i == 1){
			previous = data[data[,twinID] %in% levelsOfTwinID[i], allVars]
			previous = umx_rename(previous, replace = newNames, old = vars2keep)
		} else {
			current  = data[data[,twinID] %in% levelsOfTwinID[i], famIDPlus_vars2keep]
			current  = umx_rename(current, replace = newNames, old = vars2keep)			
			previous = merge(previous, current, by = famID, all.x = TRUE, all.y = TRUE)
		}
		# cat(paste0(levelsOfTwinID[i], " "))
	}
	# TODO umx_long2wide: Bother to check if zygosity is not NA in some member of family?
	# 	to avoid problem of NA if NA in first family member found?
	# TODO umx_long2wide: How to get unique values of passalong?
	# if(!is.na(passalong)){
		# One last look for the passalong columns
		# current  = data[, c(famID, passalong)]
		# previous = merge(previous, current, by = famID, all.x = TRUE, all.y = TRUE)
		# x = names(previous)
		# x[-which(names(x) %in% passalong)]
	# }
  return(previous)
}


#' Change data family data from wide (2 twins per row) to long format.
#'
#' @description
#' Just detects the data columns for twin 1, and twin 2, then returns them stacked
#' on top of each other (rbind) with the non-twin specific columns copied for each as well.
#'
#' @param data a dataframe containing twin data.
#' @param sep the string between the var name and twin suffix, i.e., var_T1 = _T
#' @param verbose Report the non-twin and twin columns (default = FALSE).
#' @return - long-format dataframe
#' @export
#' @family Twin Data functions
#' @examples
#' long = umx_wide2long(data = twinData, sep = "")
#' long = umx_wide2long(data = twinData, sep = "", verbose = TRUE)
#' str(long)
#' str(twinData)
umx_wide2long <- function(data, sep = "_T", verbose = FALSE) {
	# TODO umx_wide2long Assumes 2 twins: Generalize to unlimited family size.

	# 1. get the suffixed names
	T1 = umx_names(data, paste0(".", sep, "1"))
	T2 = umx_names(data, paste0(".", sep, "2"))
	# 1b and non-twin names
	nonTwinColNames = setdiff(umx_names(data), c(T1, T2))

	# 2. Remove the suffixes
	T1base = T1
	T2base = T2
	m <- regexpr(paste0(sep, "1$"), T1base)
	regmatches(T1base, m) <- ""
	m <- regexpr(paste0(sep, "2$"), T2base)
	regmatches(T2base, m) <- ""
	
	# Check they're the same
	if(!setequal(T1base, T2base)){
		stop("Twin names don't match")
	}

	# 3. 
	b1 = data[, c(nonTwinColNames, T1)]
	b2 = data[, c(nonTwinColNames, T2)]
	names(b1) = c(nonTwinColNames, T1base)
	names(b2) = c(nonTwinColNames, T1base)
	ld = rbind(b1, b2)

	twinColumns = T1base
	if(verbose){
		umx_msg(nonTwinColNames)
		umx_msg(twinColumns)
	}
	if(length(intersect(nonTwinColNames, twinColumns)) > 0){
		message("Hmm... A variable already existed matching one of the de-suffixed twin variables... 
		A second column with the same name will be created. the issue is with:", 
			omxQuotes(intersect(nonTwinColNames, twinColumns))
		)
	}
	return(ld)
}

#' Stack data like stack() does, with more control.
#'
#' @description
#' Operates like \code{\link{stack}}, but can preserve ("passalong") other variables on each row,
#' and allows the user control over the values and group column names for ease of use.
#'
#' @param x a dataframe containing twin data.
#' @param select The variables to stack (wide 2 long)
#' @param passalong Variables to preserve on each row (e.g. age)
#' @param valuesName The name for the new stacked column (default = "values")
#' @param groupName The name for the column containing the grouping variable (default = "ind")
#' @return - long-format dataframe
#' @export
#' @family Data Functions
#' @examples
#' 
#' # Base-R stack function
#' df = stack(mtcars, select = c("disp", "hp"), drop=FALSE)
#' 
#' # umx_stack, with additional variables passed along 
#' df= umx_stack(mtcars, select= c("disp", "hp"), passalong= "mpg")
#' str(df) # ind is a factor, with levels select
#' ggplot2::qplot(x = mpg, y= values, color=ind, data = df)
#' df= umx_stack(mtcars, select= c("disp", "hp"), passalong= "mpg")
#' ggplot2::qplot(x = mpg, y= values, group="ind", data = df)
umx_stack <- function(x, select, passalong, valuesName = "values", groupName = "ind") {
	# TODO: rewrite to create the full size in one go, and slot in blocks
	# initialize new dataframe
	df = x[c(passalong, select[1])]
	# rename
	names(df)= c(passalong, valuesName)
	# stack remaining columns
	for(thisVar in select[2:length(select)]) {
		tmp = x[c(passalong, thisVar)]
		names(tmp)= c(passalong, valuesName)
		df = rbind(df, tmp)
	}
	# Add column indicating origin of each value
	df[,groupName]= factor(rep(select, each = dim(x)[1]))
	return(df)
}

#' Like the php array_shift function: shifts an item off the beginning of a list
#' 
#' Returns x[1]. Has the SIDE EFFECT of assigning x to x[2:end] in the container environment.
#'
#' @param x the vector to shift
#' @return - first item of x
#' @export
#' @family Miscellaneous Utility Functions
#' @examples
#' x = c("Alice", "Bob", "Carol")
#' umx_array_shift(x) # returns "Alice"
#' x # now only 2 items (altered in containing environment)
umx_array_shift <- function(x){
	item1 = x[1]
	x <<- x[2:length(x)]
	return(item1)
}

#' umx_swap_a_block
#'
#' Swap a block of rows of a dataset between two sets of variables (typically twin 1 and twin 2)
#'
#' @param theData a data frame to swap within
#' @param rowSelector rows to swap amongst columns
#' @param T1Names the first set of columns
#' @param T2Names the second set of columns
#' @return - dataframe
#' @family Data Functions
#' @export
#' @seealso - \code{\link{subset}}
#' @examples
#' test = data.frame(
#' a = paste0("a", 1:10),
#' b = paste0("b", 1:10),
#' c = paste0("c", 1:10),
#' d = paste0("d", 1:10), stringsAsFactors = FALSE)
#' umx_swap_a_block(test, rowSelector = c(1,2,3,6), T1Names = "b", T2Names = "c")
#' umx_swap_a_block(test, rowSelector = c(1,2,3,6), T1Names = c("a","c"), T2Names = c("b","d"))
#'
umx_swap_a_block <- function(theData, rowSelector, T1Names, T2Names) {
	theRows = theData[rowSelector,]
	old_BlockTwo = theRows[,T2Names]
	theRows[,T1Names] -> theRows[, T2Names]
	theRows[,T1Names] <- old_BlockTwo
	theData[rowSelector,] <- theRows
	return(theData)
}

# =================
# = Simulate Data =
# =================

#' Simulate twin data with control over A, C, and E parameters, as well as moderation of A.
#' @description
#' Makes MZ and DZ twin data, optionally with moderated A. By default, the three variance components must sum to 1.
#' 
#' See examples for how to use this: it is pretty flexible).
#' 
#' If you provide 2 varNames, they will be used for twin 1 and twin 2. If you provide one, it will be expanded to var_T1 and var_T2
#' 
#' You supply the number of pairs of each zygosity that wish to simulate (nMZpairs, nDZpairs), along with the values of AA, CC,and EE.
#' 
#' *Note*, if you want a power calculator, see [here](https://www.people.vcu.edu/~bverhulst/power/power.html).
#' 
#' **Shortcuts**
#' 
#' You can omit nDZpairs. You can also give any 2 of A, C, or E and the function will add the value which makes the ACE total = 1.
#' 
#' **Moderation**
#' **Univariate GxE Data**
#' AA can take a list c(avg = .5, min = 0, max = 1). If specified will act like a moderated heritability, with average value = avg, and swinging
#' down to min and up to max across 3 SDs of the moderator.
#'
#' **Bivariate GxE Data**
#' 
#' To simulate data with a moderator that is not shared by both twins.
#' Moderated heritability is specified via the bivariate relationship (AA, CC, EE) and two moderators in each component.
#' AA   = list(a11 = .4, a12 = .1, a22 = .15)
#' CC   = list(c11 = .2, c12 = .1, c22 = .10)
#' EE   = list(e11 = .4, e12 = .3, e22 = .25)
#' Amod = list(Beta_a1 = .025, Beta_a2 = .025)
#' Cmod = list(Beta_c1 = .025, Beta_c2 = .025)
#' Emod = list(Beta_e1 = .025, Beta_e2 = .025)
#'
#' @param nMZpairs Number of MZ pairs to simulate
#' @param nDZpairs Number of DZ pairs to simulate (defaults to nMZpairs)
#' @param AA value for A variance. NOTE: See options for use in GxE and Bivariate GxE
#' @param CC value for C variance.
#' @param EE value for E variance.
#' @param MZr If MZr and DZr are set (default = NULL), the function returns dataframes of the request n and correlation.
#' @param DZr NULL
#' @param Amod Used for Bivariate GxE data: list(Beta_a1 = .025, Beta_a2 = .025)
#' @param Cmod Used for Bivariate GxE data: list(Beta_c1 = .025, Beta_c2 = .025)
#' @param Emod Used for Bivariate GxE data: list(Beta_e1 = .025, Beta_e2 = .025)
#' @param varNames name for variables (defaults to 'var')
#' @param mean mean for traits (default = 0) (not applied to moderated cases)
#' @param sd sd of traits (default = 1) (not applied to moderated cases)
#' @param seed Allows user to set.seed() if wanting reproducible dataset
#' @param empirical Passed to mvrnorm
#' @param nThresh  If supplied, use as thresholds and return mxFactor output? (default is not to)
#' @param sum2one  Whether to enforce AA + CC + EE summing the one (default = TRUE)
#' @return - list of mzData and dzData dataframes containing T1 and T2 plus, if needed M1 and M2 (moderator values)
#' @export
#' @family Twin Data functions
#' @seealso - \code{\link{umx_make_TwinData}}, \code{\link{umxGxEbiv}}, \code{\link{umxACE}}, \code{\link{umxGxE}}
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' # =====================================================================
#' # = Basic Example, with all elements of std univariate data specified =
#' # =====================================================================
#' tmp = umx_make_TwinData(nMZpairs = 10000, AA = .30, CC = .00, EE = .70)
#' # Show list of 2 data sets
#' str(tmp)
#' # = How to consume the built datasets =
#' mzData = tmp[[1]];
#' dzData = tmp[[2]];
#' cov(mzData); cov(dzData)
#' umxAPA(mzData)
#' str(mzData); str(dzData); 
#' 
#' # Prefer to work in path coefficient values? (little a?)
#' tmp = umx_make_TwinData(200, AA = .6^2, CC = .2^2)
#' # Check the correlations
#' umxAPA(tmp[[1]]); umxAPA(tmp[[2]])
#'
#' # =============
#' # = Shortcuts =
#' # =============
#'
#' # Omit nDZpairs (equal numbers of both by default)
#' tmp = umx_make_TwinData(nMZpairs = 100, nDZpairs = 100, AA = .36, CC = .04, EE = .60)
#' tmp = umx_make_TwinData(100, AA = 0.5, CC = 0.3) # omit any one of A, C, or E (sums to 1)
#' cov(tmp[[1]])
#' # Not limited to unit variance
#' tmp = umx_make_TwinData(100, AA = 3, CC = 2, EE = 3, sum2one = FALSE) 
#' cov(tmp[[1]])
#'
#' # =====================
#' # = Moderator Example =
#' # =====================
#'
#' x = umx_make_TwinData(100, AA = c(avg = .7, min = 0, max = 1), CC = .55, EE = .63)
#' str(x)
#'
#' # =====================
#' # = Threshold Example =
#' # =====================
#' tmp = umx_make_TwinData(100, AA = .6, CC = .2, nThresh = 3)
#' str(tmp)
#' umxAPA(tmp[[1]]); umxAPA(tmp[[2]])
#'
#'
#' # ========================
#' # = Just use MZr and DZr =
#' # ========================
#' tmp = umx_make_TwinData(100, MZr = .86, DZr= .60, varNames = "IQ")
#' umxAPA(tmp[[1]]); umxAPA(tmp[[2]])
#' 
#' # Bivariate GxSES example (see umxGxEbiv)
#' 
#' AA   = list(a11 = .4, a12 = .1, a22 = .15)
#' CC   = list(c11 = .2, c12 = .1, c22 = .10)
#' EE   = list(e11 = .4, e12 = .3, e22 = .25)
#' Amod = list(Beta_a1 = .025, Beta_a2 = .025)
#' Cmod = list(Beta_c1 = .025, Beta_c2 = .025)
#' Emod = list(Beta_e1 = .025, Beta_e2 = .025)
#' tmp = umx_make_TwinData(5000, AA =AA, CC = CC, EE = EE, Amod = Amod, Cmod =Cmod, Emod =Emod)
#'# List of 2
#'#  $ mzData:'data.frame':	5000 obs. of  6 variables:
#'#   ..$ defM_T1: num [1:5000] -1.424 -1.606 -0.749 -0.358 -0.208 ...
#'#   ..$ defM_T2: num [1:5000] -1.703 -1.125 -1.136 0.366 -0.864 ...
#'#   ..$ M_T1   : num [1:5000] -1.424 -1.606 -0.749 -0.358 -0.208 ...
#'#   ..$ var_T1 : num [1:5000] -1.1197 -0.3074 -0.4156 -0.4149 0.0739 ...
#'#   ..$ M_T2   : num [1:5000] -1.703 -1.125 -1.136 0.366 -0.864 ...
#'#   ..$ var_T2 : num [1:5000] 0.381 -1.275 -1.114 1.297 -1.53 ...
#'#  $ dzData:'data.frame':	5000 obs. of  6 variables:
#'#   ..$ defM_T1: num [1:5000] 0.253 -0.402 0.545 -1.494 -0.278 ...
#'#   ..$ defM_T2: num [1:5000] 1.7587 0.3025 -0.3864 0.0737 0.514 ...
#'#   ..$ M_T1   : num [1:5000] 0.253 -0.402 0.545 -1.494 -0.278 ...
#'#   ..$ var_T1 : num [1:5000] -0.835 -0.305 -0.299 -1.576 -0.26 ...
#'#   ..$ M_T2   : num [1:5000] 1.7587 0.3025 -0.3864 0.0737 0.514 ...
#'#   ..$ var_T2 : num [1:5000] -0.418 0.678 -0.78 -0.312 -0.272 ...
#' 
#' # TODO tmx example showing how moderation of A introduces heteroskedasticity in a regression model.
#' # More residual variance at one extreme of the x axis (moderator) 
#' # m1 = lm(var_T1~ M_T1, data = x); 
#' # x = rbind(tmp[[1]], tmp[[2]])
#' # plot(residuals(m1)~ x$M_T1, data=x)
#' @md
umx_make_TwinData <- function(nMZpairs, nDZpairs = nMZpairs, AA = NULL, CC = NULL, EE = NULL,  varNames = "var",  mean=0, sd=1, nThresh = NULL, sum2one = TRUE, seed = NULL, empirical = FALSE, MZr= NULL, DZr= MZr, Amod = NULL, Cmod = NULL, Emod = NULL) {
	if(!is.null(seed)){
		set.seed(seed = seed)
	}
	# Function caps the moderator effect at -3 and +3 SD
	if(!is.null(MZr)){
		if(is.null(DZr)){
			stop("Both MZr and DZr must be set if you want to generate data matching MZ and DZ correlations.")
		}
		mzCov = matrix(nrow = 2, byrow = T, c(
			1, MZr,
			MZr, 1)
		);
		dzCov = matrix(nrow = 2, byrow = T, c(
			1, DZr,
			DZr, 1)
		);
		sdMat = diag(rep(sd, 2))
		mzCov = sdMat %*% mzCov %*% sdMat
		dzCov = sdMat %*% dzCov %*% sdMat
		mzData = mvrnorm(n = nMZpairs, mu = c(mean, mean), Sigma = mzCov, empirical = empirical);
		dzData = mvrnorm(n = nDZpairs, mu = c(mean, mean), Sigma = dzCov, empirical = empirical);
		mzData = data.frame(mzData)
		dzData = data.frame(dzData)
		if(length(varNames) > 1){
			names(mzData) = names(dzData) = varNames
		} else {
			names(mzData) = names(dzData) = umx_paste_names(varNames, "_T")
		}
		return(list(mzData = mzData, dzData = dzData))
	}
	if(length(AA) == 1){
		# standard ACE, no moderation
		if(sum(c(is.null(AA), is.null(CC), is.null(EE))) > 2){
			stop("You must set at least 2 of AA, CC, and EE", call. = FALSE)
		}
		if(is.null(EE)){
			EE  = (1 - (AA + CC))
		} else if(is.null(CC)) {
			CC  = (1 - (AA + EE))
		} else if(is.null(AA)) {
			AA  = (1 - (CC + EE))
		}
		if(any(c(AA, CC, EE)< 0)){
			lowValue = c("AA", "CC", "EE")[ which(c(AA, CC, EE) < 0) ]
			stop(paste("Hmm, each of the AA, CC, and EE variance components must be postive, but ", lowValue, " was negative."), call. = FALSE)		
		}
		if(sum2one && (sum(c(AA, CC, EE)) != 1)){
			stop("Hmm, AA + CC + EE must sum to 1, unless you don't want them to (in which case set sum2one = FALSE)", call. = FALSE)		
		}
		# Report to user
		print(c(AA = AA, CC = CC, EE = EE))
		print(round(c(a = sqrt(AA), c = sqrt(CC), e = sqrt(EE)), 2))
		
		AC  =  AA + CC
		hAC = (.5 * AA) + CC
		ACE = AC + EE
		mzCov = matrix(nrow = 2, byrow = T, c(
			ACE, AC,
			AC, ACE)
		);
		dzCov = matrix(nrow = 2, byrow = T, c(
			ACE, hAC,
			hAC, ACE)
		);
		sdMat = diag(rep(sd, 2))
		mzCov = sdMat %*% mzCov %*% sdMat
		dzCov = sdMat %*% dzCov %*% sdMat
		
		mzData = mvrnorm(n = nMZpairs, mu = c(mean, mean), Sigma = mzCov, empirical = empirical);
		dzData = mvrnorm(n = nDZpairs, mu = c(mean, mean), Sigma = dzCov, empirical = empirical);
		mzData = data.frame(mzData)
		dzData = data.frame(dzData)
		if(length(varNames) > 1){
			names(mzData) = names(dzData) = varNames
		} else {
			names(mzData) = names(dzData) = umx_paste_names(varNames, "_T")
		}
	}else if(!is.null(Amod)){
		# Bivariate Moderation example
		
		# Moderator (M) path components
		am = sqrt(AA$a11) # The Cholesky moderator A coefficients.
		cm = sqrt(CC$c11) # The Cholesky moderator C coefficients.
		em = sqrt(EE$e11) # The Cholesky moderator E coefficients.

		# Cross paths M -> T in Cholesky
		a12  = sqrt(AA$a12)	# A covariances in terms of Cholesky paths
		c12  = sqrt(CC$c12)	# C
		e12  = sqrt(EE$e12)	# E
		Beta_a1 = Amod$Beta_a1	# A paths are moderated
		Beta_c1 = Cmod$Beta_c1	# C mod
		Beta_e1 = Emod$Beta_e1	# E mod

		# Trait "T"
		a22 = sqrt(AA$a22)	# A variance components of the trait ModelA (see above)
		c22 = sqrt(CC$c22)	# C
		e22 = sqrt(EE$e22)	# E	
		Beta_a2 = Amod$Beta_a2	# A moderation
		Beta_c2 = Cmod$Beta_c2	# C
		Beta_e2 = Emod$Beta_e2	# E

		# Simulate data by generating scores on the latent variables A, C, E of
		# the moderator and A2, C2, and E2 of the trait, conditional on the moderator. 
		# These are uncorrelated as the latter is trait | moderator.

		# Define the expected correlation matrices for MZ and DZ
		sMZtmp = zero = matrix(data = 0, nrow = 6, ncol = 6)
		diag(sMZtmp) = 1
		sDZtmp = sMZtmp
		sMZtmp[4, 1] = sMZtmp[1, 4] = 1.0 # A
		sDZtmp[4, 1] = sDZtmp[1, 4] = 0.5 # A
		sMZtmp[5, 2] = sMZtmp[2, 5] = sDZtmp[5, 2] = sDZtmp[2, 5] = 1 # C

		# varNames = c('defm_T1', 'defm_T2', 't_T1', 'm_T1', 'm_T2', 't_T2')
		# dimnames(sMZtmp) = list(varNames, varNames)

		sigmaMZ = rbind(cbind(sMZtmp, zero),
						cbind(zero, sMZtmp))
		sigmaDZ = rbind(cbind(sDZtmp, zero),
						cbind(zero, sDZtmp))

		# Latent scores: A C E (m)   A C E (t|m)
		# M data cols 1:6, Trait conditional on M cols 7-12
		MZLatent = mvrnorm(nMZpairs, mu = rep(0, 12), Sigma = sigmaMZ, empirical = empirical)
		DZLatent = mvrnorm(nDZpairs, mu = rep(0, 12), Sigma = sigmaDZ, empirical = empirical)

		# Data matrices to be filled with content
		tdatmz = mdatmz = matrix(data = 0, nrow = nMZpairs, ncol = 2)
		tdatdz = mdatdz = matrix(data = 0, nrow = nDZpairs, ncol = 2)

		# Create the phenotypic scores
		for (i in 1:nMZpairs) {
			# Generate Twin 1 phenotypic moderation score
			mod = am * MZLatent[i, 1] + cm * MZLatent[i, 2] + em * MZLatent[i, 3] 
			# create the phenotypic trait score, depending on M and on T|M
			#           T|M                                            M
			atmp1 = (a22 + Beta_a2 * mod) * MZLatent[i, 1+6] + (a12 + Beta_a1 * mod) * MZLatent[i, 1]
			ctmp1 = (c22 + Beta_c2 * mod) * MZLatent[i, 2+6] + (c12 + Beta_c1 * mod) * MZLatent[i, 2]
			etmp1 = (e22 + Beta_e2 * mod) * MZLatent[i, 3+6] + (e12 + Beta_e1 * mod) * MZLatent[i, 3]
			j = 1 # J = 1 twin 1 mz.
			mdatmz[i,j] = mod			# moderator
			tdatmz[i,j] = atmp1 + ctmp1 + etmp1	# trait

			# twin2
			mod = am * MZLatent[i, 4] + cm * MZLatent[i, 5] + em * MZLatent[i, 6]
			atmp1 = (a22 + Beta_a2 * mod) * MZLatent[i, 4+6] + (a12 + Beta_a1 * mod) * MZLatent[i, 4]
			ctmp1 = (c22 + Beta_c2 * mod) * MZLatent[i, 5+6] + (c12 + Beta_c1 * mod) * MZLatent[i, 5]
			etmp1 = (e22 + Beta_e2 * mod) * MZLatent[i, 6+6] + (e12 + Beta_e1 * mod) * MZLatent[i, 6]
			j = 2	# twin 2
			mdatmz[i, j] = mod
			tdatmz[i, j] = atmp1 + ctmp1 + etmp1
		} 

		# Same for DZ twins (might differ in number)
		for (i in 1:nDZpairs) {
			j = 1
			mod = am * DZLatent[i, 1] + cm * DZLatent[i, 2] + em * DZLatent[i, 3]
			atmp1 = (a22 + Beta_a2 * mod) * DZLatent[i, 1+6] + (a12 + Beta_a1 * mod) * DZLatent[i, 1]
			ctmp1 = (c22 + Beta_c2 * mod) * DZLatent[i, 2+6] + (c12 + Beta_c1 * mod) * DZLatent[i, 2]
			etmp1 = (e22 + Beta_e2 * mod) * DZLatent[i, 3+6] + (e12 + Beta_e1 * mod) * DZLatent[i, 3]
			mdatdz[i,j] = mod
			tdatdz[i,j] = atmp1 + ctmp1 + etmp1
			j = 2 # twin 2
			mod = am * DZLatent[i, 4] + cm * DZLatent[i, 5] + em * DZLatent[i, 6]
			atmp1 = (a22 + Beta_a2 * mod) * DZLatent[i, 4+6] + (a12 + Beta_a1 * mod) * DZLatent[i, 4]
			ctmp1 = (c22 + Beta_c2 * mod) * DZLatent[i, 5+6] + (c12 + Beta_c1 * mod) * DZLatent[i, 5]
			etmp1 = (e22 + Beta_e2 * mod) * DZLatent[i, 6+6] + (e12 + Beta_e1 * mod) * DZLatent[i, 6]
			mdatdz[i,j] = mod
			tdatdz[i,j] = atmp1 + ctmp1 + etmp1
		}

		# Convert to data frames, reorder columns and add names. 
		mzData = as.data.frame(cbind(mdatmz, mdatmz, tdatmz))
		dzData = as.data.frame(cbind(mdatdz, mdatdz, tdatdz))
		mzData = mzData[,c(1, 2, 3, 5, 4, 6)]
		dzData = dzData[,c(1, 2, 3, 5, 4, 6)]
		# TODO use var names
		colnames(mzData) = c('defM_T1', 'defM_T2', 'M_T1', 'var_T1', 'M_T2', 'var_T2')
		colnames(dzData) = c('defM_T1', 'defM_T2', 'M_T1', 'var_T1', 'M_T2', 'var_T2')
	} else {
		# Univariate Moderator
		if(any(c(is.null(AA), is.null(CC), is.null(EE)))){
			stop("For moderation, you must set all three of AA, CC, and EE", call. = FALSE)
		}
		avgA = AA["avg"]
		# minA applied at -3 SD
		# maxA applied at +3 SD
		SES_2_A_beta = (AA["max"] - AA["min"])/6

		mzData = data.frame(T1 = rep(NA, nMZpairs), T2 = rep(NA, nMZpairs), M1 = rep(NA, nMZpairs), M2 = rep(NA, nMZpairs))
		dzData = data.frame(T1 = rep(NA, nDZpairs), T2 = rep(NA, nDZpairs), M1 = rep(NA, nDZpairs), M2 = rep(NA, nDZpairs))
		# ==========
		# = Do MZs =
		# ==========
		SESlist = rnorm(n = nMZpairs, mean = 0, sd = 1)
		# qplot(SESlist)
		j = 1
		for (thisSES in SESlist) {
			# thisSES = 0
			AA = max(0, (avgA + (thisSES * SES_2_A_beta)))
			# CC = 0.0
			# EE = 0.1
			AC  = AA + CC
			ACE = AA + CC + EE
			mzCov = matrix(nrow = 2, byrow = T, c(
				ACE, AC,
				AC , ACE)
			);
			# print(mzCov)
			# MASS:: package
			mzPair = mvrnorm(n = 1, mu = c(0, 0), Sigma = mzCov, empirical = empirical);
			mzData[j, ] = c(mzPair, thisSES, thisSES)
			j = j + 1
		}

		# ==========
		# = Do DZs =
		# ==========
		SESlist = rnorm(n = nDZpairs, mean = 0, sd = 1)
		j = 1
		for (thisSES in SESlist) {
			# thisSES = -5
			AA = max(0, (avgA + (thisSES * SES_2_A_beta)))
			hAC = (.5 * AA) + CC
			ACE = AA + CC + EE
			dzCov = matrix(nrow = 2, byrow = T, c(
				ACE, hAC,
				hAC, ACE)
			);
			dzPair = mvrnorm(n = 1, mu = c(0, 0), Sigma = dzCov, empirical = empirical);
			dzData[j,] = c(dzPair, thisSES, thisSES)
			j = j + 1
		}
		names(mzData) = names(dzData) = c(umx_paste_names(varNames, "_T"), "M_T1", "M_T2")
	}
	if(!is.null(nThresh)){
		# TODO umx_make_TwinData: Combine all columns for more accuracy 
		tmp = rbind(mzData, dzData)
		levelLabels = paste0("quantile", 1:(nThresh+1))
		for (i in 1:length(varNames)) {
			t1 = paste0(varNames[i], sep = "_T1")
			t2 = paste0(varNames[i], sep = "_T2")
			cutPoints = quantile(rbind(tmp[, t1], tmp[, t2]), probs = c((1:nThresh) / (nThresh + 1)), na.rm = TRUE)
			mzData[,t1] = cut(mzData[,t1], breaks = c(-Inf, cutPoints, Inf), labels = levelLabels) 
			mzData[,t2] = cut(mzData[,t2], breaks = c(-Inf, cutPoints, Inf), labels = levelLabels) 
			dzData[,t1] = cut(dzData[,t1], breaks = c(-Inf, cutPoints, Inf), labels = levelLabels) 
			dzData[,t2] = cut(dzData[,t2], breaks = c(-Inf, cutPoints, Inf), labels = levelLabels) 
			# Make the ordinal variables into mxFactors (ensure ordered is TRUE, and require levels)
			ordinalVars = umx_paste_names(varNames, "_T")
			mzData[, ordinalVars] = umxFactor(mzData[, ordinalVars])
			dzData[, ordinalVars] = umxFactor(dzData[, ordinalVars])
		}
	}	
	return(list(mzData = mzData, dzData = dzData))
}

#' Simulate Mendelian Randomization data
#'
#' umx_make_MR_data returns a dataset containing 4 variables: A variable of interest (Y), a putative cause (X),
#' a qtl (quantitative trait locus) influencing X, and a confounding variable (U) affecting both X and Y.
#'
#' The code to make these Data. Modified from Dave Evans 2016 Boulder workshop talk.
#' 
#' @param nSubjects Number of subjects in sample
#' @param Vqtl Variance of QTL affecting causal variable X (Default 0.02) 
#' @param pQTL Decreaser allele frequency (Default 0.5)
#' @param bXY  Causal effect of X on Y (Default 0.1)
#' @param bUX  Confounding effect of confounder 'U' on X (Default 0.5) 
#' @param bUY  Confounding effect of confounder 'U' on Y (Default 0.5) 
#' @param seed value for the random number generator (Default 123)
#' @return - data.frame
#' @export
#' @family Data Functions
#' @seealso umx_make_TwinData
#' @examples
#' df = umx_make_MR_data(10000)
#' str(df)
#' \dontrun{
#' m1 = umxTwoStage(Y ~ X, ~qtl, data = df)
#' plot(m1)
#' }
umx_make_MR_data <- function(nSubjects = 1000, Vqtl = .02, bXY = 0.1, bUX = 0.5, bUY = 0.5, pQTL = 0.5, seed = 123) {	
	# nSubjects  = 50,000 # Individuals
	# bXY  = 0.1      # Causal effect of X on Y
	# bUX  = 0.5      # Confounding effect of U on X
	# bUY  = 0.5      # Confounding effect of U on Y
	# pQTL = 0.5      # Decreaser allele frequency
	set.seed(seed)
	b_qtl_x  = sqrt(Vqtl) # Path coefficient between SNP and X
	q = 1 - pQTL # Increaser allele frequency
	a = sqrt(1/(2 * pQTL * q)) # Genotypic value for genetic variable of variance 1.0
	# Residual variance in variable X (so variance adds up to one)
	Vex  <- (1- Vqtl - bUX^2)
	sdex <- sqrt(Vex) # Residual standard error in variable X
	
	# Residual variance for Y variable (so var sums to 1)
	Vey = 1 - (bXY^2 + 2*bXY*bUX*bUY + bUY^2) 
	sdey <- sqrt(Vey) # Residual standard error in variable Y
 
	# Simulate individual genotypic and phenotypic values
	qtl <- sample(c(-a, 0, a), nSubjects, replace = TRUE, prob = c(pQTL^2, 2 * pQTL * q, q^2)) 
	U <- rnorm(nSubjects, 0, 1) #Confounding variables
	X <- b_qtl_x * qtl + bUX * U + rnorm(nSubjects, 0, sdex) # X variable
	Y <- bXY * X + bUY * U + rnorm(nSubjects, 0, sdey) # Y variable
	# Recode SNP qtl using traditional 0, 1, 2 coding
	qtl <- replace(qtl, qtl ==  a, 2)
	qtl <- replace(qtl, qtl ==  0, 1)
	qtl <- replace(qtl, qtl == -a, 0)
	MR_data = data.frame(X = X, Y = Y, U = U, qtl = qtl)
	# save(MR_data, file = "~/bin/umx/data/MR_data.rda")
}

#' umx_make_fake_data
#'
#' This function takes as argument an existing dataset, which 
#' must be either a matrix or a data frame. Each column of the 
#' dataset must consist either of numeric variables or ordered 
#' factors. When one or more ordered factors are included, 
#' then a heterogeneous correlation matrix is computed using 
#' John Fox's polycor package. Pairwise complete observations 
#' are used for all covariances, and the exact pattern of 
#' missing data present in the input is placed in the output,
#' provided a new sample size is not requested. Warnings from
#' the polycor::hetcor function are suppressed.
#'
#' @param dataset The original dataset of which to make a simulacrum
#' @param digits = Round the data to the requested digits (default = 2)
#' @param n Number of rows to generate (NA = all rows in dataset)
#' @param use.names Whether to name the variables (default = TRUE)
#' @param use.levels = Whether to use existing levels (default = TRUE)
#' @param use.miss Whether to have data missing as in original (defaults to TRUE)
#' @param mvt.method = Passed to hetcor (default = "eigen")
#' @param het.ML = Passed to hetcor (default = FALSE)
#' @param het.suppress Passed to hetcor (default = TRUE)
#' @return - new dataframe
#' @family Data Functions
#' @export
#' @examples
#' fakeCars = umx_make_fake_data(mtcars)
umx_make_fake_data <- function(dataset, digits = 2, n = NA, use.names = TRUE, use.levels = TRUE, use.miss = TRUE, mvt.method = "eigen", het.ML = FALSE, het.suppress = TRUE){
  # requires mvtnorm & polycor
  # requires data frame or matrix
  if((is.data.frame(dataset)+is.matrix(dataset))==0){
    warning("Data must be a data frame or matrix")
  }
  # organization
  row <- dim(dataset)[1] # number of rows
  if(is.na(n))(n <- row) # sets unspecified sample size to num rows
  col <- dim(dataset)[2] # number of columns
  del <- is.na(dataset)  # records position of NAs in dataset
  if(n != row){
    select <- round(runif(n, 0.5, row+.49),0)
    del    <- del[select,]
  }
  num <- rep(NA, col)    # see what's not a factor
  ord <- rep(NA, col)    # see what's an ordered factor

  # which columns are numeric (the others are factors)?
  for (i in 1:col){
    num[i] <- is.numeric(dataset[,i])
    ord[i] <- is.ordered(dataset[,i])
  }

  # check for unordered factors
  location <- !(num|ord)
  unorder  <- sum(location)

  if(unorder>0)warning(
    paste("Unordered factor detected in variable(s):", 
      names(dataset)[location]
    )
  )

  # if everything is numeric, don't invoke polycor
  if(sum(!num) == 0){
    # generate data with rmvnorm
	# depends on mvtnorm::rmvnorm
    fake <- mvtnorm::rmvnorm(n, apply(dataset, 2, mean, na.rm = TRUE),
		cov(dataset, use = "pairwise.complete.obs"), mvt.method)

    # round the data to the requested digits
    fake <- round(fake, digits)

    # insert the missing data, if so requested
    if(use.miss == TRUE)(fake[del] <- NA)

    # give the variables names, if so requested
    if(use.names == TRUE)(names(fake) <- names(dataset))

    # return the new data
    return(fake)
  }

  # if there are factors, we start here

  # find the variable means (constrain to zero for factors)
  mixedMeans <- rep(0, col)
  mixedMeans[num] <- apply(dataset[, num], 2, mean, na.rm = TRUE)

  # estimate a heterogeneous correlation matrix
  if (het.suppress == TRUE){
	  suppressWarnings(het <- polycor::hetcor(dataset, ML = het.ML))
  } else {
	  het <- polycor::hetcor(dataset, ML = het.ML)	
  }
  mixedCov <- het$correlations

  # make a diagonal matrix of standard deviations to turn the 
  # correlation matrix into a covariance matrix
  stand <- matrix(0, col, col)
  diag(stand) <- rep(1, col)
  diag(stand)[num] <- apply(dataset[,num], 2, sd, na.rm=TRUE)
  # pre and post multiply hetero cor matrix by diagonal sd matrix
  mixedCov <- stand %*% mixedCov %*% stand

  # generate the data
  fake <- as.data.frame(mvtnorm::rmvnorm(row, mixedMeans, mixedCov, mvt.method))

  # insert the missing data, if so requested
  if(use.miss == TRUE)(fake[del] <- NA)

  # turn the required continuous variables into factors
  for (i in (1:col)[!num]){
    # the original data for this column
    old <- dataset[,i]
   
    # the new data for this column, omiting NAs
    new <- fake[!is.na(fake[,i]),i]

    # what are the levels of the original factor?
    lev <- levels(old)

    # establish cutpoints in new variable from cdf of old factor
    cut <- cumsum(table(old))/(sum(!is.na(old)))

    # put continuous variable into a matrix, repeating value across columns
    wide <- matrix(new, length(new), length(lev))

    # put the cutpoints in a matrix, repeating the cut point values across rows
    crit <- matrix(quantile(new, cut), length(new), length(lev), byrow=TRUE)

    # for each value (row of the wide matrix), 
    # how many cutpoints is the value greater than?
    # number of cutpoints surpassed=category
    fake[!is.na(fake[,i]),i] <- apply(wide>crit, 1, sum)

    # make it a factor
    fake[,i] <- factor(fake[,i], ordered=TRUE)

    # give the new factor the same levels as the old variable
    if(length(levels(fake[,i]))!=length(lev))message(
      paste("Fewer categories in simulated variable", 
      names(fake)[i], "than in input variable", names(dataset)[i]))
    if(use.levels==TRUE&(length(levels(fake[,i]))==length(lev))){
      levels(fake[,i]) <- lev} else (levels(fake[,i]) <- 1:length(lev))
  }

  # Round the data to the requested digits
  fake[,num] <- round(fake[,num], digits)

  # Give the variables names, if so requested
  if(use.names==TRUE)(names(fake) <- names(dataset))
  
  # Return the new data
  return(fake)
}

#' Turn a cov matrix into raw data with umx_cov2raw
#'
#' Turns a covariance matrix into comparable raw data :-)
#'
#' @param myCovariance a covariance matrix
#' @param n how many rows of data to return
#' @param means the means of the raw data (defaults to 0)
#' @return - data.frame
#' @export
#' @seealso - \code{\link{cov2cor}}
#' @family Data Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' covData <- matrix(nrow=6, ncol=6, byrow=TRUE, dimnames=list(paste0("v", 1:6), paste0("v", 1:6)),
#' data = c(0.9223099, 0.1862938, 0.4374359, 0.8959973, 0.9928430, 0.5320662,
#'            0.1862938, 0.2889364, 0.3927790, 0.3321639, 0.3371594, 0.4476898,
#'            0.4374359, 0.3927790, 1.0069552, 0.6918755, 0.7482155, 0.9013952,
#'            0.8959973, 0.3321639, 0.6918755, 1.8059956, 1.6142005, 0.8040448,
#'            0.9928430, 0.3371594, 0.7482155, 1.6142005, 1.9223567, 0.8777786,
#'            0.5320662, 0.4476898, 0.9013952, 0.8040448, 0.8777786, 1.3997558))
#' myData = umx_cov2raw(covData, n = 100, means = 1:6)
umx_cov2raw <- function(myCovariance, n, means = 0) {
	# depends on MASS::mvrnorm
	if(!umx_is_cov(myCovariance, boolean = TRUE)){
		stop("myCovariance must be a covariance matrix")
	}
	if(length(means) == 0){
		means = rep(means, dim(myCovariance)[2])
	} else {
		if(length(means) != dim(myCovariance)[2]){
			stop("means must have length 1 or the number of columns in the matrix. You gave me ", dim(myCovariance)[2], 
			 " columns of cov matrix, but ", length(means), " means.")
		}
	}
	out = MASS::mvrnorm (n = n, mu = means, Sigma = myCovariance);
	out = data.frame(out);  names(out) <- colnames(myCovariance);
	return(out)
}

# =============
# = Read data =
# =============

#' Read lower-triangle of data matrix from console or file
#'
#' umx_read_lower will read a lower triangle of data, either from the 
#' console, or from file, and return a full matrix, optionally coerced to
#' positive definite. This is useful, especially when copying data from a paper
#' that includes just the lower triangle of a correlation matrix.
#'
#' @param file Path to a file to read (Default "" will read from user input)
#' @param diag Whether the data include the diagonal. Defaults to TRUE
#' @param names The default names for the variables.
#' Defaults to as.character(paste("X", 1:n, sep=""))
#' @param ensurePD Whether to coerce the resultant matrix to positive definite (Defaults to FALSE)
#' @return - \code{\link{matrix}}
#' @export
#' @family Data Functions
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}
#' @examples
#' require(umx) # for umxRAM
#' \dontrun{
#' df = umx_read_lower(file = "", diag = F, ensurePD=TRUE)
#' 0.38
#' 0.86	0.30
#' 0.42	0.12	0.27
#' 0.66	0.21	0.38	0.18
#' 0.80	0.13	0.50	0.25	0.43
#' 0.19	0.11	0.19	0.12	-0.06	0.22
#' 0.27	0.09	0.33	0.05	-0.04	0.28	.73
#' 0.52	0.17	0.38	0.37	0.39	0.44	0.18	0.13
#' 
#' IQtests = c("brainstorm", "matrix", "moral", "shopping", "typing")
#' n       = c("C", IQtests, "avgIQ", "maxIQ", "video")
#' 
#' dimnames(df) = list(n,n)
#' 
#' m1 = umxRAM("wooley", data = mxData(df, type="cov", numObs = 90),
#' 	umxPath("g", to = IQtests),
#' 	umxPath(var = "g", fixedAt=1),
#' 	umxPath(var = IQtests)
#' )
#' summary(m1)
#' }
umx_read_lower <- function(file="", diag=TRUE, names=as.character(paste("X", 1:n, sep="")), ensurePD=FALSE){
	# modified from John Fox's sem package, to remove dependency on X11
	# depends on Matrix::nearPD
    elements <- scan(file=file)
    m <- length(elements)
    d <- if (diag) 1 else -1
    n <- floor((sqrt(1 + 8*m) - d)/2)
    if (m != n*(n + d)/2) 
        stop("wrong number of elements (cannot make square matrix)")
    if (length(names) != n) stop("wrong number of variable names")
    X <- diag(n)
    X[upper.tri(X, diag=diag)] <- elements
    rownames(X) <- colnames(X) <- names
	X = t(X)
	otherTri <- t(X)
	X[upper.tri(X, diag=F)] <- otherTri[upper.tri(otherTri, diag=F)]
	if(ensurePD){
		# move to positive definite if not already there
		if(all(eigen(X)$values>0)){
			# already positive definite
		} else {
			message("matrix modified to be to positive definite")
			X = as.matrix(Matrix::nearPD(X)$mat)
		}
	}
	return(X)
}
    
#' Make pairs of  bin & continuous columns to represent censored data
#'
#' Takes a dataframe of left-censored variables (vars with a floor effect) and does two things to it:
#' 1. It creates new binary (1/0) copies of each column (with the suffix "bin"). These contain 0 where
#'    the variable is below the minimum and NA otherwise.
#' 2. In each existing variable, it sets all instances of min for that var to NA
#' 
#' @param data A \code{\link{data.frame}} to convert
#' @param vars The variables to process
#' @param suffixes Suffixes if the data are family (wide, more than one persona on a row)
#' @return - copy of the dataframe with new binary variables and censoring
#' @export
#' @family Data Functions
#' @references - \url{https://github.com/tbates/umx}, \url{https://tbates.github.io}, \url{https://openmx.ssri.psu.edu}
#' @examples
#' df = umx_make_bin_cont_pair_data(mtcars, vars = c("mpg"))
#' str(df)
#' df[order(df$mpg), c(1,12)]
#' # Introduce a floor effect
#' tmp = mtcars; tmp$mpg[tmp$mpg<=15]=15
#' tmp$mpg_T1 = tmp$mpg_T2 = tmp$mpg
#' df = umx_make_bin_cont_pair_data(tmp, vars = c("mpg"), suffixes = c("_T1", "_T2"))
#' df[order(df$mpg), 12:15]
umx_make_bin_cont_pair_data <- function(data, vars = NULL, suffixes=NULL){
	if(!is.null(suffixes)){
		umx_check(length(suffixes) < 3, "stop", "suffixes must have length == 2")
		longVars = umx_paste_names(vars, suffixes = suffixes)
	}else{
		longVars = vars
	}
	umx_check_names(longVars, data = data, die = TRUE)
	if(!is.null(suffixes)){
		# Get minimum scores from a long version of the vars
		for (i in 1:length(suffixes)) {
			vars_Ti = umx_paste_names(vars, suffixes = suffixes[i])
			if(i == 1){
				tmp = data[, vars_Ti, drop = FALSE]
				names(tmp) = vars
			} else {
				tmp2 = data[, vars_Ti, drop = FALSE]
				names(tmp2) = vars
				tmp = rbind(tmp, tmp2)
			}
		}
		listOfMins = umx_apply(min, tmp, by = "columns", na.rm = TRUE)
	} else {
		listOfMins = umx_apply(min, data[, vars, drop = FALSE], by = "columns", na.rm = TRUE)
	}
	# blank suffix to make this work when there is none
	if(is.null(suffixes)){ suffixes = ""}
	var_i = 1
	for (var in vars) {
		for (thisSuffix in suffixes) {
			thisVarName = paste0(var, thisSuffix)
			thisBinName = paste0(var, "bin", thisSuffix)
			data[,thisBinName] = (data[, thisVarName] <= listOfMins[var_i])
			data[,thisBinName] = mxFactor(data[, thisBinName], c(TRUE, FALSE), c("low", "high"))

			# Set NA if FALSE
			lowScores = data[,thisBinName] == "low"
			data[lowScores , thisVarName] = NA
			data[!lowScores, thisBinName] = NA
		}
		var_i = var_i + 1
	}
	return(data)
}

#' Create a matrix of correlations for variables of diverse types (binary, ordinal, continuous)
#'
#' umxHetCor is a helper to 
#' 1. return just the correlations from John Fox's polycor::hetcor function
#' 2. If you give it a covariance matrix, return the nearest positive-definite correlation matrix.
#'
#' @param data A \code{\link{data.frame}} of columns for which to compute heterochoric correlations. OR an existing covariance matrix.
#' @param ML Whether to use Maximum likelihood computation of correlations (default = FALSE)
#' @param use How to handle missing data: Default= "pairwise.complete.obs". Alternative ="complete.obs".
#' @param treatAllAsFactor Whether to treat all columns as factors, whether they are or not (Default = FALSE)
#' @param verbose How much to tell the user about what was done.
#' @param return Return just the correlations (default) or the hetcor object (contains, method, SEs etc.)
#' @param std.err Compute the SEs? (default = FALSE)
#' @return - A matrix of correlations
#' @family Data Functions
#' @family Miscellaneous Stats Helpers
#' @export
#' @references - 
#' @examples
#' umxHetCor(mtcars[,c("mpg", "am")])
#' umxHetCor(mtcars[,c("mpg", "am")], treatAllAsFactor = TRUE, verbose = TRUE)
umxHetCor <- function(data, ML = FALSE, use = c("pairwise.complete.obs", "complete.obs"), treatAllAsFactor = FALSE, verbose = FALSE, return= c("correlations", "hetcor object"), std.err = FALSE){
	# Depends on polycor::hetcor
	return = match.arg(return)
	use = match.arg(use)
	if(treatAllAsFactor){
		n = ncol(data)
		for (i in 1:n) {
			data[,i] = factor(data[,i])
		}
	}
	hetc = hetcor(data, ML = ML, use = use, std.err = std.err)
	if(verbose){
		print(hetc)
	}
	if(return == "correlations"){
		return(hetc$correlations)
	} else {
		return(hetc)
	}
}

#' Convert lower-only matrix data to full (or enforce symmetry on a full matrix)
#'
#' Takes a vector of the lower-triangle of cells in a matrix as you might read-in
#' from a journal article), OR a matrix (for instance from a "lower" \code{\link{mxMatrix}}, 
#' and returns a full matrix, copying the lower triangle into the upper.
#' 
#' *note*: Can also take lower data presented in the form of a data.frame. Note also, if 
#' presented with a full matrix, the function will return a matrix with  symmetry enforced. Can be
#' handy when you have a "nearly-symmetrical" matrix (with differences in the 10th decimal place).
#' 
#' @param lower.data An \code{\link{mxMatrix}}
#' @param diag A boolean specifying whether the lower.data includes the diagonal
#' @param byrow Whether the matrix is to be filled by row or by column (default = TRUE)
#' @param dimnames Optional dimnames for the matrix (defaults to NULL)
#' @return - \code{\link{mxMatrix}}
#' @family Data Functions
#' @export
#' @references - \url{https://www.github.com/tbates/umx}
#' @examples
#' 
#' # 1. Test with a vector in byrow = TRUE order) 
#' tmp = c(
#' 	1.0000, 
#' 	0.6247, 1.0000,
#' 	0.3269, 0.3669, 1.0000,
#' 	0.4216, 0.3275, 0.6404, 1.0000,
#' 	0.2137, 0.2742, 0.1124, 0.0839, 1.0000,
#' 	0.4105, 0.4043, 0.2903, 0.2598, 0.1839, 1.0000,
#' 	0.3240, 0.4047, 0.3054, 0.2786, 0.0489, 0.2220, 1.0000,
#' 	0.2930, 0.2407, 0.4105, 0.3607, 0.0186, 0.1861, 0.2707,  1.0000,
#' 	0.2995, 0.2863, 0.5191, 0.5007, 0.0782, 0.3355, 0.2302,  0.2950, 1.0000,
#' 	0.0760, 0.0702, 0.2784, 0.1988, 0.1147, 0.1021, 0.0931, -0.0438, 0.2087, 1.000
#' )
#' x = umx_lower2full(tmp, diag = TRUE)
#' # check
#' isSymmetric(x)
#' 
#' # 2. Test with matrix input
#' tmpn = c("ROccAsp", "REdAsp", "FOccAsp", "FEdAsp", "RParAsp", 
#'          "RIQ", "RSES", "FSES", "FIQ", "FParAsp")
#' tmp = matrix(nrow = 10, ncol = 10, byrow = TRUE, dimnames = list(tmpn,tmpn), data = 
#' 	c(1.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000,  0.0000, 0.0000, 0,
#' 	0.6247, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000,  0.0000, 0.0000, 0,
#' 	0.3269, 0.3669, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000,  0.0000, 0.0000, 0,
#' 	0.4216, 0.3275, 0.6404, 1.0000, 0.0000, 0.0000, 0.0000,  0.0000, 0.0000, 0,
#' 	0.2137, 0.2742, 0.1124, 0.0839, 1.0000, 0.0000, 0.0000,  0.0000, 0.0000, 0,
#' 	0.4105, 0.4043, 0.2903, 0.2598, 0.1839, 1.0000, 0.0000,  0.0000, 0.0000, 0,
#' 	0.3240, 0.4047, 0.3054, 0.2786, 0.0489, 0.2220, 1.0000,  0.0000, 0.0000, 0,
#' 	0.2930, 0.2407, 0.4105, 0.3607, 0.0186, 0.1861, 0.2707,  1.0000, 0.0000, 0,
#' 	0.2995, 0.2863, 0.5191, 0.5007, 0.0782, 0.3355, 0.2302,  0.2950, 1.0000, 0,
#' 	0.0760, 0.0702, 0.2784, 0.1988, 0.1147, 0.1021, 0.0931, -0.0438, 0.2087, 1)
#' )
#' x = umx_lower2full(tmp, diag= TRUE)
#' isSymmetric(x)
#' 
#' # 3. Test with lower-vector, no diagonal.
#' tmp = c(
#' 	0.6247,
#' 	0.3269, 0.3669,
#' 	0.4216, 0.3275, 0.6404,
#' 	0.2137, 0.2742, 0.1124, 0.0839,
#' 	0.4105, 0.4043, 0.2903, 0.2598, 0.1839,
#' 	0.3240, 0.4047, 0.3054, 0.2786, 0.0489, 0.2220,
#' 	0.2930, 0.2407, 0.4105, 0.3607, 0.0186, 0.1861, 0.2707, 
#' 	0.2995, 0.2863, 0.5191, 0.5007, 0.0782, 0.3355, 0.2302,  0.2950,
#' 	0.0760, 0.0702, 0.2784, 0.1988, 0.1147, 0.1021, 0.0931, -0.0438, 0.2087
#' )
#' umx_lower2full(tmp, diag = FALSE)
#' 	
#' 	# An example with byrow = FALSE
#' 	
#' 	ldiag = c(
#' 	1, -.17, -.22, -.19, -.12, .81, -.02, -.26, -.2, -.15,
#' 	1, .11, .2, .21, -.01, .7, .1, .7, .1, .17, .22,
#' 	1, .52, .68, -.12, .09, .49, .27, .46,
#' 	1, .5, -.06, .17, .26, .80, .31,
#' 	1, -.1, .19, .36, .23, .42,
#' 	1, .02, -19, -.06, -.06,
#' 	1, .1, .18, .27,
#' 	1, .51, .7,
#' 	1, .55, 
#' 	1)
#' umx_lower2full(tmp, byrow = FALSE, diag = TRUE)

umx_lower2full <- function(lower.data, diag = NULL, byrow = TRUE, dimnames = NULL) {
	if(is.null(diag)){
		stop("Please set diag explicitly to TRUE or FALSE")
	} else if( !diag %in% c(TRUE, FALSE) ){
		stop("diag must be one of TRUE or FALSE.")
	}

	if(is.matrix(lower.data)||is.data.frame(lower.data)){
		# Copy the transpose of the lower triangle to the
		# upper triangle
		mat = lower.data
		mat[upper.tri(mat)] <- t(mat)[upper.tri(mat)]
	} else {
		len = length(lower.data)
		if(diag) {
			# len * 2 = ((x+.5)^2)-.25
			size = len * 2
			size = size + .25
			size = sqrt(size)
			size = size - .5;
		}else{
			# no diag
			# len = (x*((x+1)/2))-x	
			# .5*(x-1)*x
			size = len * 2
			# (x-.5)^2 - .25
			size= size + .25
			size = sqrt(size)
			size = size + .5;
		}
		# mat = diag(10)
		mat = diag(size)
		if(byrow){
			# oddly enough, flow data into upper triangle, then transform to lower
			mat[upper.tri(mat, diag = diag)] <- lower.data
			tmat = t(mat)
			mat[lower.tri(mat, diag = FALSE)] <- tmat[lower.tri(tmat, diag = FALSE)]
		}else{
			# bycolumn: flow data into columns of lower triangle, then transform to upper
			mat[lower.tri(mat, diag = diag)] <- lower.data
			tmat = t(mat)
			mat[upper.tri(mat, diag = FALSE)] <-tmat[upper.tri(tmat, diag = FALSE)]
		}
	}

	if(!is.null(dimnames)){
		if(typeof(dimnames) == "list"){
			dimnames(mat) = dimnames
		} else {
			dimnames(mat) = list(dimnames, dimnames)
		}
	}
	return(mat)
}

#' umxPadAndPruneForDefVars
#'
#' Replaces NAs in definition slots with the mean for that variable ONLY where all data are missing for that twin
#'
#' @param df the dataframe to process
#' @param varNames list of names of the variables being analysed
#' @param defNames list of covariates
#' @param suffixes that map names on columns in df (i.e., c("T1", "T2"))
#' @param highDefValue What to replace missing definition variables (covariates) with. Default = 99
#' @param rm = how to handle missing values in the varNames. Default is "drop_missing_def", "pad_with_mean")
#' @return - dataframe
#' @export
#' @family Data Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' \dontrun{
#' data(twinData)
#' sum(is.na(twinData$ht1))
#' df = umxPadAndPruneForDefVars(twinData, varNames = "ht", defNames = "wt", c("1", "2"))
#' }
umxPadAndPruneForDefVars <- function(df, varNames, defNames, suffixes, highDefValue = 99, rm = c("drop_missing_def", "pad_with_mean")) {
	# df = twinData
	# varNames = varNames
	# defNames = covNames
	# suffixes = suffixes
	# highDefValue = -100000
	# rm = "pad_with_mean"

	numTwinsPerFamily = length(suffixes)
	message("Working with ", numTwinsPerFamily, " twins per family:", paste(suffixes, collapse = ", "))
	message("Checking varNames: ", paste(varNames, collapse = ", "))
	# get mean values for each definition Variable
	meanDefVarValues = colMeans(df[, paste0(defNames, suffixes[1]), drop=F], na.rm = TRUE)
	numRows = dim(df)[1]

	for (i in 1:numTwinsPerFamily) {
		# i = 1
		# for twin i
		defVars = paste0(defNames, suffixes[i])
		defData = df[, defVars, drop = F]
		Vars    = paste0(varNames, suffixes[i])
		varData = df[, Vars, drop = F]
		allDataMissing = rep(FALSE, numRows)
		missingDefVars = rep(FALSE, numRows)
		for (n in 1:numRows) {
			# n = 1
			allDataMissing[n] = all(is.na(varData[n,]))
			defsMissing = is.na(defData[n,])
			missingDefVars[n] = any(defsMissing)
			if(allDataMissing[n]){
				if(missingDefVars[n]){
					df[n, defVars] = highDefValue
				}
			} else {
				if(missingDefVars[n]){
					df[n, defVars[defsMissing]] = meanDefVarValues[defsMissing]
				}
			}
		}
		message(numRows, " families found")
		message(sum(allDataMissing), " missing all DVs", " for twin ", i, " (", sum(!allDataMissing), " had at least one datapoint).")
		message("Of these, ", sum(allDataMissing & missingDefVars), " were NA for at least one definition variable and for these subjects, all definition vars were set to highDefValue (", highDefValue, ")")
		message(sum(!allDataMissing & missingDefVars), " were NA for at least one definition variable but had some measured data.\n")
		message(" for these subjects, definition vars were set to the mean for the dataset... not perfect but likely adequate response.")
		warning("I am not yet checking for ordinal vars etc.")
	}
	return(df)
}

#' get mat[r,c] style cell address from an mxMatrix
#'
#' Sometimes you want these :-) This also allows you to change the matrix name: useful for using mxMatrix addresses in an mxAlgebra.
#'
#' @param mat an mxMatrix to get address labels from
#' @param free how to filter on free (default = NA: take all)
#' @param newName = NA
#' @return - a list of bracket style labels
#' @export
#' @family Advanced Model Building Functions
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
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
#' umx_get_bracket_addresses(m1$matrices$A, free= TRUE)
# "stdA[1,6]" "stdA[2,6]" "stdA[3,6]" "stdA[4,6]" "stdA[5,6]"
umx_get_bracket_addresses <- function(mat, free = NA, newName = NA) {
	# c("stdS[6,7]", "stdS[7,7]")
	if(is.na(newName)){
		matName = mat$name
	} else {
		matName = newName
	}
	rows <- nrow(mat$free)
	cols <- ncol(mat$free)
	d1 <- expand.grid(matName, "[", 1:rows, ",", 1:cols, "]", stringsAsFactors = FALSE)	
	addys = c()
	for (i in 1:(rows*cols)) {
		addys = c(addys, paste(d1[i,], collapse = ""))
	}
	addys = matrix(addys, rows,cols)
	if(is.na(free) ){
		return(addys)
	} else if (free == TRUE){
		return(addys[mat$free == TRUE])
	} else if (free == FALSE){
		return(addys[mat$free == TRUE])
	} else {
		stop("free must be one of NA TRUE or FALSE")	
	}
}

umx_accumulate <- function(FUN = nlevels, from = c("columns", "rows"), of_df = NULL) {
	# accumulate(nlevels, fromEach = "column", of_df = ordinalColumns)
	from = match.arg(from)
	out = c()
	if(from == "columns"){
		for(n in 1:ncol(of_df)){
			out[n] = nlevels(of_df[,n])
		}
	} else {
		for(n in 1:nrow(of_df)){
			out[n] = nlevels(of_df[n,])
		}
	}
	return(out)
}

umx_str2Algebra <- function(algString, name = NA, dimnames = NA) {
	# stringToMxAlgebra(paste(rep("A", nReps), collapse = " %*% "), name="whatever")
	eval(substitute(mxAlgebra(tExp, name=name, dimnames=dimnames), list(tExp = parse(text=algString)[[1]])))
	# This is useful because it lets you use paste() and rep() to quickly and easily insert values from R variables into the string, then parse the string as an mxAlgebra argument.
	# Use case: include a matrix exponent (that is A %*% A %*% A %*% A...) with a variable exponent. With this function, the code goes:
}

# =============================
# = Standardization Functions =
# =============================


#' Return a standardized version of a Structural Model
#'
#' umx_standardize takes umx models, including RAM and twin models, and returns a standardized version.
#'
#'
#' @description
#' Return the standardized version of a model (such as ACE, CP etc.)
#'
#' Versions exist for RAM, ACE, ACEv, ACEcov, IP, CP and GxE models.
#'
#' @param model The \code{\link{mxModel}} whose fit will be reported.
#' @param ... Other parameters.
#' @family Advanced Model Building Functions
#' \url{https://www.github.com/tbates/umx}
#' @export
umx_standardize <- function(model, ...){
	UseMethod("umx_standardize", model)
}

#' @export
umx_standardize.default <- function(model, ...){
	stop("umx_standardize is not defined for objects of class:", class(model))
}

#' Return a standardized version of a Structural Model
#'
#' umx_standardize_RAM takes a RAM-style model, and returns standardized version.
#'
#' @param model The \code{\link{mxModel}} you wish to standardize
#' @param ... Other options
#' @return - standarized RAM model.
#' @family Reporting functions
#' @references - \url{https://github.com/tbates/umx}
#' @export
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
#' m1 = umx_standardize_RAM(m1, return = "model")
#' m1 = umx_standardize(m1, return = "model")
#' summary(m1)
umx_standardize_RAM <- function(model, ...) {
	if (!umx_is_RAM(model)){
		stop("I need a RAM model")
	}
	output <- model$output
	# Stop if there is no objective function.
	if (is.null(output))stop("Provided model has no objective function, and thus no output. I can only standardize models that have been run!")
	# Stop if there is no output
	if (length(output) < 1){
		message("Model has not been run yet")
		return(model)
	}
	# Get the names of the A, S and M matrices
	nameA <- model$expectation$A
	nameS <- model$expectation$S
	nameM <- model$expectation$M
	# Get the A and S matrices, and make an identity matrix
	A <- model[[nameA]]
	S <- model[[nameS]]
	I <- diag(nrow(S$values))
	
	# this can fail (non-invertible etc. so we wrap it in try-catch)
	tryCatch({	
		# Calculate the expected covariance matrix
		IA <- solve(I - A$values)
		expCov <- IA %*% S$values %*% t(IA)
		# Return 1/SD to a diagonal matrix
		InvSD <- 1/sqrt(diag(expCov))
		# Give the inverse SDs names, because mxSummary treats column names as characters
		names(InvSD) <- as.character(1:length(InvSD))
		if (!is.null(dimnames(A$values))){names(InvSD) <- as.vector(dimnames(S$values)[[2]])}
		# Put the inverse SDs into a diagonal matrix (might as well recycle I matrix from above)
		diag(I) <- InvSD
		# Standardize the A, S and M matrices
		#  A paths are value*sd(from)/sd(to) = I %*% A %*% solve(I)
		#  S paths are value/(sd(from*sd(to))) = I %*% S %*% I
		stdA <- I %*% A$values %*% solve(I)
		stdS <- I %*% S$values %*% I
		# Populate the model
		model[[nameA]]$values[,] <- stdA
		model[[nameS]]$values[,] <- stdS
		if (!is.na(nameM)){model[[nameM]]$values[,] <- rep(0, length(InvSD))}
	}, warning = function(cond) {
	    # warning-handler-code
        message(cond)
	}, error = function(cond) {
	    cat("The model could not be standardized")
        message(cond)
	}, finally = {
	    # cleanup-code
	})
	# Return the model, if asked
	invisible(model)
}
#' @export
umx_standardize.MxModel <- umx_standardize_RAM

#' umx_standardize_ACE
#'
#' Standardize an ACE model
#'
#' @param model an \code{\link{umxACE}} model to standardize
#' @param ... Other options
#' @return - Standardized ACE \code{\link{umxACE}} model
#' @export
#' @family zAdvanced Helpers
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(twinData)
#' selDVs = c("bmi1", "bmi2")
#' mzData <- twinData[twinData$zyg == 1, selDVs][1:80,] # 80 pairs for speed
#' dzData <- twinData[twinData$zyg == 3, selDVs][1:80,]
#' m1  = umxACE(selDVs = selDVs, dzData = dzData, mzData = mzData)
#' std = umx_standardize_ACE(m1)
umx_standardize_ACE <- function(model, ...) {
	if(typeof(model) == "list"){ # Call self recursively
		for(thisFit in model) {
			message("Output for Model: ", thisFit$name)
			umx_standardize(thisFit)
		}
	} else {
		if(!umx_has_been_run(model)){
			stop("I can only standardize ACE models that have been run. Just do\n",
			"yourModel = mxRun(yourModel)")
		}
		selDVs = dimnames(model$top.expCovMZ)[[1]]
		nVar <- length(selDVs)/2;
		# Calculate standardized variance components
		a  <- mxEval(top.a, model); # Path coefficients
		c  <- mxEval(top.c, model);
		e  <- mxEval(top.e, model);

		A  <- mxEval(top.A, model); # Variances
		C  <- mxEval(top.C, model);
		E  <- mxEval(top.E, model);
		Vtot = A + C + E;           # Total variance
		I  <- diag(nVar);           # nVar Identity matrix
		SD <- solve(sqrt(I * Vtot)) # Inverse of diagonal matrix of standard deviations  (same as "(\sqrt(I.Vtot))~"
	
		# Standardized _path_ coefficients ready to be stacked together
		model$top$a$values = SD %*% a; # Standardized path coefficients
		model$top$c$values = SD %*% c;
		model$top$e$values = SD %*% e;
		return(model)
	}
}
#' @export
umx_standardize.MxModelACE <- umx_standardize_ACE


#' umx_standardize_ACEcov
#'
#' Standardize an ACE model with covariates
#'
#' @param model an \code{\link{umxACEcov}} model to standardize
#' @param ... Other options
#' @return - Standardized \code{\link{umxACEcov}} model
#' @export
#' @family zAdvanced Helpers
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' require(umx)
#' data(twinData)
#' twinData$age1 = twinData$age2 = twinData$age
#' selDVs  = c("bmi")
#' selCovs = c("ht") # silly example
#' selVars = umx_paste_names(c(selDVs, selCovs), sep = "", suffixes= 1:2)
#' mzData = subset(twinData, zyg == 1, selVars)[1:80, ]
#' dzData = subset(twinData, zyg == 3, selVars)[1:80, ]
#' m1 = umxACEcov(selDVs = selDVs, selCovs = selCovs, dzData = dzData, mzData = mzData, 
#' 	 sep = "", autoRun = TRUE)
#' fit = umx_standardize_ACEcov(m1)
umx_standardize_ACEcov <- function(model, ...) {
	if(typeof(model) == "list"){ # call self recursively
		for(thisFit in model) {
			message("Output for Model: ",thisFit$name)
			umx_standardize(thisFit)
		}
	} else {
		if(!umx_has_been_run(model)){
			stop("I can only standardize models that have been run. Just do\n",
			"yourModel = mxRun(yourModel)")
		}
		if(!is.null(model$top$a_std)){
			# Standardized general path components
			model$top$a$values = model$top$a_std$result # standardized a
			model$top$c$values = model$top$c_std$result # standardized c
			model$top$e$values = model$top$e_std$result # standardized e
		} else {
			stop("Please run umxACEcov(..., std = TRUE). All I do is copy a_std values into a..., so model has to have been run!")
		}
		return(model)
	}
}

#' @export
umx_standardize.MxModelACEcov <- umx_standardize_ACEcov


#' umx_standardize_IP
#'
#' This function simply copies the standardized IP components into the ai ci ei and as cs es matrices
#'
#' @param model an \code{\link{umxIP}} model to standardize
#' @param ... Other options
#' @return - standardized IP \code{\link{umxIP}} model
#' @export
#' @family zAdvanced Helpers
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' \dontrun{
#' model = umx_standardize_IP(model)
#' }
umx_standardize_IP <- function(model, ...){
	if(!is.null(model$top$ai_std)){
		# Standardized general path components
		model$top$ai$values = model$top$ai_std$result # standardized ai
		model$top$ci$values = model$top$ci_std$result # standardized ci
		model$top$ei$values = model$top$ei_std$result # standardized ei
	    # Standardized specific coeficients
		model$top$as$values = model$top$as_std$result # standardized as
		model$top$cs$values = model$top$cs_std$result # standardized cs
		model$top$es$values = model$top$es_std$result # standardized es
	} else {
		stop("Please run umxIP(..., std = TRUE). All I do is copy ai_std values into ai..., so they have to be run!")
	}
	return(model)
}
#' @export
umx_standardize.MxModelIP <- umx_standardize_IP

#' umx_standardize_CP
#'
#' This function simply inserts the standardized CP components into the ai ci ei and as cs es matrices
#'
#' @param model an \code{\link{umxCP}} model to standardize
#' @param ... Other options
#' @return - standardized \code{\link{umxCP}} model
#' @export
#' @family zAdvanced Helpers
#' @references - \url{https://tbates.github.io}, \url{https://github.com/tbates/umx}
#' @examples
#' \dontrun{
#' model = umx_standardize_CP(model)
#' }
umx_standardize_CP <- function(model, ...){
	if(!is.null(model$top$as_std)){
		# Standardized general path components
		# Standardized cp loadings
		model@submodels$top$cp_loadings@values = model$top$algebras$cp_loadings_std$result 
		# Standardized specific path coefficients
		model@submodels$top$as@values = model$top$as_std$result # standardized as
		model@submodels$top$cs@values = model$top$cs_std$result # standardized cs
		model@submodels$top$es@values = model$top$es_std$result # standardized es
		return(model)
	} else {
		selDVs = dimnames(model$top.expCovMZ)[[1]]
		nVar   = length(selDVs)/2;
		nFac   = dim(model$top$matrices$a_cp)[[1]]	
		# Calculate standardized variance components
		a_cp = mxEval(top.a_cp , model); # nFac * nFac path matrix flowing into cp_loadings array
		c_cp = mxEval(top.c_cp , model);
		e_cp = mxEval(top.e_cp , model);
		as = mxEval(top.as, model); # Specific factor path coefficients
		cs = mxEval(top.cs, model);
		es = mxEval(top.es, model);
		cp_loadings = mxEval(top.cp_loadings, model); # nVar * nFac matrix
		A  = mxEval(top.A, model);  # Variances
		C  = mxEval(top.C, model);
		E  = mxEval(top.E, model);
		Vtot = A + C + E; # total variance
		nVarIden = diag(nVar)
		SD       = solve(sqrt(nVarIden * Vtot)); # inverse of diagonal matrix of standard deviations  (in classic MX -> "(\sqrt(I.Vtot))~"
		# Standardize loadings on Common factors
		std_commonLoadings = SD %*% cp_loadings; # Standardized path coefficients (general factor(s))
		as_std = SD %*% as; # Standardized path coefficients (nVar specific factors matrices)
		cs_std = SD %*% cs;
		es_std = SD %*% es;
	    # Standardized common and specific path coefficients
		model$top$cp_loadings$values = std_commonLoadings # standardized cp loadings
		model$top$as$values = as_std # standardized as
		model$top$cs$values = cs_std # standardized cs
		model$top$es$values = es_std # standardized es
		return(model)
	}
}
#' @export
umx_standardize.MxModelCP <- umx_standardize_CP

