.pep <- function(expr) {
	## Parse then evaluate a character vector (expr), returning AND printing the
	## result if the result is visible (ie: the REP parts of the REPL).
	## Modelled on the source() function.
	## Syntax errors will be produced by the parse function.
	## Evaluation errors will be produced by the eval.with.vis function.
	## Warnings are explicitly trapped and printed, because JRI doesn't
	## output them to the console when options(warn = 0) for expressions 
	## evaluated via calls to parseAndEval. 
	## Errors are not suppressed by JRI and output straight to the console.
	## NB: warnings are printed at the end of the evaluation of all lines
	## in the expr, as opposed to after each line as it's executed.
	## NB: because warnings are muffled, last.warning won't contain any
	## warnings generated by expr

	localWarnings <- list()
	
	#wrap in try so if it errors this function will continue to execute 
	#and print any warnings
	result <- try(withCallingHandlers(
		.Internal(eval.with.vis(parse(text=expr), .GlobalEnv, baseenv())),
		
			## trap and record warning in localWarnings list
			warning = function(w) {
				## because w$call can be NULL, we must wrap in list()
				## as per R FAQ 7.1
				localWarnings[length(localWarnings)+1] <<- list(w$call)
				names(localWarnings)[length(localWarnings)] <<- w$message
				
 				## don't print warning to console
				invokeRestart("muffleWarning")  
			}
			))
			
	if (!is(result,"try-error") && result$visible) {
		## print result if visible
		show(result$value)
	}
	
	if (length(localWarnings) > 0) {
		## explicitly print warnings if they exist
		show(structure(localWarnings, class = "warnings"))
	}
	
	## return value
	if (!is(result,"try-error")) {
		result$value
	}
}