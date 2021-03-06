# Common functions for analysing data in microsimulation models.
# 
# Author: Oliver Mannion
###############################################################################

ROW <- 1
COL <- 2
ZDIM <- 3

cat("Common.r: Creating common functions\n")

a <- function (mylist) {
	## alias for toArray
	toArray(mylist)
}

addFreqs <- function (bf, outvars, wgtsname="weightScenario") {
	varnames <- names(outvars)
	
	# get frequency tables for all varnames from bf 
	results <- lapply(varnames, function(x) wtdtablecols(bf[[x]], bf[[wgtsname]]))
	
	# add frequency tables in the Z dimension to each freq in outvars
	results <- mapply(abind, outvars, results, MoreArgs=list(along=ZDIM), SIMPLIFY = FALSE)
	
	lapply(results, function (x) {
				attr(x, "meta") <- c(weighting=wgtsname);x } )
	
}

addMeans <- function (bf, outvars, logiset = NULL, wgtsname="weightScenario", grpbycoding = NULL) {
	#for each X in outvars, calculate lblmeancols of names(X)
	#and add the result back into the Z dimension of X.
	#eg: addMeans(children, allrunsmean$males.by.ethnicity.base, childset$males, wgtsname="weightBase", codings$ethnicity)
	#    lblmeancols(children, childset$males, "o.gptotvis", wgtsname="weightBase", codings$ethnicity)
	
	varnames <- names(outvars)
	
	# get mean for all varnames from bf 
	results <- lapply(varnames, function(x) lblmeancols(bf, logiset, x, wgtsname, grpbycoding))
	
	# add frequency tables in the Z dimension to each freq in outvars
	outvars <- mapply(abind, outvars, results, MoreArgs=list(along=ZDIM), SIMPLIFY = FALSE)

	# abind does not preserve names of dimensions or attributes, so we add
	# them back here
	
	mapply(function(ov,r){
				#add back names of dimension 
				names(dimnames(ov)) <- names(dimnames(r))
				#add back meta attribute
				attr(ov,"meta") <- attr(r, "meta")
				#return
				ov
			}, outvars, results, SIMPLIFY=FALSE )
}

addRowPercents <- function (counts) {
	#adds row percentages to a set of counts
	#eg: addRowPercents(yearlyFreq(children$sol, "sol"))
	pcents <- prop.table(counts,1) * 100
	
	# add (%) to the end of column headings
	dimnames(pcents)[[2]] <- sapply(dimnames(pcents)[[2]], paste, "(%)")
	
	combined <- cbind(counts, pcents)
	names(dimnames(combined)) <- names(dimnames(counts))
	
	#keep meta attribute
	attr(combined, "meta") <- attr(counts, "meta")
	
	combined
}

applyAddMeans <- function(xlist, xlistspec, bf) {
	# accepts a list. each element X of the xlist contains a list of varnames
	# to execute addMeans over using the attributes from element S from xlistspec
	#
	# An example of X:
	#   $ males.by.ethnicity.scenario:List of 3
	#     ..$ o.gptotvis: NULL
	#     ..$ o.hadmtot : NULL
	#     ..$ o.houtptot: NULL
	#
	# An example of S:
	#   $ males.by.ethnicity.scenario:List of 3
	#     ..$ wgtsname   : chr "weightScenario"
	#     ..$ logiset    : atomic [1:1153] TRUE FALSE TRUE TRUE TRUE TRUE ...
	#     .. ..- attr(*, "desc")= chr "males only"
	#     ..$ grpbycoding: atomic [1:3] 1 2 3
	#     .. ..- attr(*, "varname")= chr "r1stchildethn"
	#
	# xlist <- allrunsmean
	# x <- allrunsmean$males.by.ethnicity.base
	# bf <- children
	# eg: allrunsmean <- applyAddMeans(allrunsmean, allrunsmean.spec, children)
	
	mapply(function(x,s) {
				addMeans(bf, x, s$logiset, s$wgtsname, s$grpbycoding) 
			}, xlist, xlistspec, SIMPLIFY = FALSE)
}

library(abind)
arrZAdd <- function(m, arrName) {
	#add the 2d matrix m to the 3d array specified by the string arrName
	#in the next z dimension slot
	#eg: arrZAdd(matrix(1:12,3,4), "arr3d")
	# m <- matrix(1:12,3,4)
	# dimnames(m) <- list(letters=c("A","B","C"), numbers=c("1st","2nd","3rd","4th"))
	# arrZAdd(m, "arr3d")
	
	if (length(dim(m)) != 2) {
		firstParamName <- as.character(sys.call())[2]
		stop(gettextf("'%s' must have 2 dimensions\n",firstParamName))
	}
	
	#create new NULL variable if arrName doesn't exist
	if (!exists(arrName)) {
		assign(arrName, NULL, envir = .GlobalEnv)
	}
	
	#get current value of arrName
	arr <- eval(parse(text=arrName))
	
	#bind m to the 3rd dimension of arr
	arr <- abind(arr,m,along=3)
	
	#add back names of dimension because they get lost in abind
	names(dimnames(arr)) <- names(dimnames(m))
	
	#keep meta attribute
	attr(arr, "meta") <- attr(m, "meta")	
	
	#save to arrName
	assign(arrName, arr, envir = .GlobalEnv)
}

arrZMean <- function (arrZ) {
	#mean across Z dimension of 3d array 
	#eg: arrZMean(freqSingle)
	result <- apply(arrZ,c(1,2),mean)
	
	#keep meta attribute
	attr(result, "meta") <- attr(arrZ, "meta")
	
	result
}


cAdd <- function(vec, arrName, colName) {
	#add the vector to the 2d array specified by the string arrName
	#in the next column slot
	#eg: cAdd(c(1,2,3,4,5), "arr2d", "col1")
	# vec <- c(1,2,3)
	# names(vec) <- c("a","b","c")
	# cAdd(vec, "arr2d", "col1")
	
	#create new NULL variable if arrName doesn't exist
	if (!exists(arrName)) {
		assign(arrName, NULL, envir = .GlobalEnv)
	}
	
	#get current value of arrName
	arr <- eval(parse(text=arrName))
	
	#bind vec to the arr with column name = colName
	arr <- cbind(arr, `colnames<-`(cbind(vec), colName))
	
	#keep meta attribute
	attr(arr, "meta") <- attr(vec, "meta")	
	
	#save to arrName
	assign(arrName, arr, envir = .GlobalEnv)
}

collapseZdim <- function (xarray) {
	#collapse the Z dimension of a 3D array into cols in a 2D array
	#eg: xarray <- runs.all.mean$all.base$o.gptotvis
	#eg: xarray <- runs.all.mean$all.by.gender.base$o.gptotvis
	#eg: collapseZdim(runs.all.mean$all.base$o.gptotvis)
	#eg: collapseZdim(runs.all.mean$all.by.gender.base$o.gptotvis)
	
	result <- apply(xarray, ZDIM, function(x) {x})
	
	#copy names, dimnames, and meta attribute to the result
	rows <- dim(xarray)[ROW]
	cols <- dim(xarray)[COL]
	zdims <- dim(xarray)[ZDIM]
	dim(result) <- c(rows, cols*zdims)
	dimnames(result)[[ROW]] <- dimnames(xarray)[[ROW]] 
	dimnames(result)[[COL]] <- rep(dimnames(xarray)[[COL]], zdims)
	names(dimnames(result)) <- names(dimnames(xarray))[-ZDIM] 
	attr(result, "meta") <- attr(xarray, "meta")
	
	result
}

#' Lookup description of variable x in the dictionary
#' first determines the name of variable x, then does the lookup
#' 
#' @examples
#' x <- env.base$years1_5$results$freqs$all$z1msmokeLvl1
#' x <- env.base$years1_5$results$freqs$grouped$by.ethnicity$z1msmokeLvl1
#' dictLookup(x)
#' dictLookup("burt")
#' dictLookup(c(1,2))
#' dictLookup(freqSingle)
#' dictLookup("single")
#' dictLookup("don't exist")
#' dictLookup(runs.mean.freq$base$o.chres)
dictLookup <- function(x) {
	
	name <- c()
	grouping <- c()
	set <- c()
	weighting <- c()
	meta <- attr(x, "meta")
	
	#get the variable name
	if (!is.null(meta)) {
		#use the meta attribute
		name <- meta["varname"]
		if (!is.na(meta["grouping"])) grouping <- paste(" by ", meta["grouping"], sep="")
		if (!is.na(meta["grpby.tag"])) grouping <- paste(" by ", dictLookup(meta["grpby.tag"]), sep="")
		if (!is.na(meta["set"])) set <- paste(" (", meta["set"], ")", sep="")
		if (!is.na(meta["weighting"])) weighting <- meta["weighting"]
		
	} 
	
	# if no meta, or no name from meta
	if (is.null(name) || is.na(name)) {
		
		if (class(x) %in% c("matrix", "array", "table") && !is.null(names(dimnames(x)))) {
			#get name from names of dimensions
			namesdim <- names(dimnames(x))
			namesdim <- stripEmpty(namesdim) #remove NAs and empty strings
			
			# get last dim for name
			name <- namesdim[length(namesdim)]
			
		} else if (class(x) == "character") {
			#get name from first position of char vector
			name <- x[1]
			
		} else {
			#fail
			firstParamName <- as.character(sys.call())[2]
			stop(gettextf("cannot determine varname from %s: no meta or names", firstParamName))
		}
	}
	
	#lookup name in dictionary
	if (!name %in% names(dict)) {
		stop(gettextf("'%s' does not exist in the data dictionary", name))
	}
	
	desc <- dict[[name]]
	
	if (is.null(desc)) {
		stop(gettextf("variable named '%s' does not exist in data dictionary", name))
		name <- dname
	}
	
	#add grouping, weighting, and set descriptions (if any)
	weightdesc <- ifelse(weighting == "weightBase", "", " scenario")
	paste(desc, grouping, weightdesc, set, sep="")
}

err <- function (values) {
	## calc the 95% error from the t Distribution
	## see http://www.cyclismo.org/tutorial/R/confidence.html
	## used by meanOfRuns
	qt(0.975,df=length(values)-1)*sd(values)/sqrt(length(values))
}

factorWeights <- function (xvecfactors, desiredProp) {
	#generates a weighting for each factor in xvecfactors such that 
	#propWtdtable(xvecfactors, factorWeights(xvecfactors, desiredProp)) == desiredProp
	#
	#eg: xvecfactors = children$SESBTH
	#eg: desiredProp <- c(0.2,0.3,0.5)
	#eg: factorWeights(children$SESBTH,c(0.2,0.3,0.5)) 
	
	# get existing proportions of factor levels
	baseProp <- prop.table(table(xvecfactors))
	
	# weight for each factor level is desiredProp/baseProp
	weight <- desiredProp/baseProp
	
	# get position of each factor level (each xvecfactors) in weight names
	weightPos <- match(xvecfactors, names(weight))
	
	# get weight for xvecfactors
	result <- sapply(weightPos, function (x) weight[x], USE.NAMES = FALSE )
	names(result) <- NULL
	result
}

freq <- function(variable, varname) {
	# frequency table with percent
	# v = variable
	#
	# eg: freq(a(children$msmoke)[,1], "msmoke")
	# eg: freq(a(children$msmoke)[,2], "msmoke")
	tbl <- as.data.frame( table(variable, dnn = varname), responseName = "Frequency")
	tbl$Percent <- prop.table(tbl$Frequency) * 100
	tbl$"Cumulative Percent" <- cumsum (tbl$Percent) 
	tbl
}

globalNamed <- function (varname, x) {
	#save x into global variable, ie: top frame, not just this function
	#using the supplied varname
	assign(varname, x, envir = .GlobalEnv)	
}

global <- function (x) {
	#save x into global variable as it's own name
	param1Name <- as.character(sys.call())[2]
	globalNamed(param1Name, x)
}

labelColFromVec <- function (xlist, colnameslist) {
	# set the columns names of each x in xlist to
	# each char vector c in colnameslist
	labelCol <- function(x, colnames) {dimnames(x)[[COL]] <- colnames;x}
	mapply(labelCol,
			xlist, colnameslist, SIMPLIFY = FALSE)
}	

labelColTitleFromList <- function(xnamedlist) {
	# names each object's column names with the 
	# object's name in the named list
	labelCol <- function(x,xname) {names(dimnames(x))[COL] <- c(xname);x }
	mapply(labelCol, xnamedlist, names(xnamedlist), SIMPLIFY = FALSE)
}

labelTitle <- function (xm, along, title) {
	# names the "along" dimension with "title"
	# eg: labelTitle(y, ROW, "Year") 
	names(dimnames(xm))[[along]] <- title
	xm
}

labelprefixseq <- function(xm, along, prefix) {
	# names the "along" dimension of xm with a prefixed sequence
	# eg: labelColWithSeq(y, COL, "Run") #COL will be labelled "Run 1", "Run 2"..etc.
	if (is.null(dimnames(xm))) {
		stop('No dimnames')
	}
	dimnames(xm)[[along]] <- paste(prefix, seq(dim(xm)[along]))
	xm
}

labelseq <- function(xm, along, title) {
	# names the "along" dimension of xm with a sequence
	# and give that dimension the name "title"
	# eg: labelseq(y, ROW, "Year") 
	dimnames(xm)[[along]] <- seq(dim(xm)[along])
	names(dimnames(xm))[[along]] <- title
	xm
}

orderByDictLookup <- function (...) {
	# order the list by the results returned applying
	# dictLookup to the list's elements
	xlist <- c(...)
	ordering <- sort.list(sapply(xlist, dictLookup))
	xlist[ordering]
}

prependRowMeanInfo <- function (xm) {
	#prepend mean, err, left & right CI to each row of matrix 
	#
	#input: a matrix/dataframe containing columns of values
	#       to calculate mean info for, eg:
	#
	#          Run 1        Run 2
	#1  0.0039392527 4.189704e-03
	#2  0.0052892006 5.554406e-03
	#3  0.0500477200 4.921984e-02
	#4  0.0061327012 6.273054e-03
	#
	#output: the original values plus the additional variables: 
	#Mean, Err, Left, Right prepended to the start of each row
	#
	#eg: xm <- ymo.gptotvis
	#eg: prependRowMeanInfo(ymo.gptotvis)
	
	#calculate mean of each row
	meanRuns <- apply(xm,1,mean)
	
	#calculate error of each row
	errRuns <- apply(xm,1,err)
	
	#calculate left CI
	leftRuns <- meanRuns - errRuns
	
	#calculate right CI
	rightRuns <- meanRuns + errRuns
	
	#return with mean, error, and confidence intervals prepended
	result <- cbind(Mean = meanRuns, Err = errRuns, 
			Left = leftRuns, Right = rightRuns, xm)
	
	names(dimnames(result)) <- names(dimnames(xm))
	
	#keep meta attribute
	attr(result, "meta") <- attr(xm, "meta")
	
	result
}

propWtdtable <- function (variable, wgts) {
	#return proportions of variable weighted
	#eg: propWtdtable(people$sex, people$weightBase)
	prop.table(wtdtable(variable, wgts))
}

removeObs <- function(xframe, indices) {
	#remove observations (ie. rows) of 
	#xframe specified by indices
	#eg: DF <- data.frame(x = c(1, 2, 3), y = c(0, 10, NA))
	#removeObs(DF, c(1,3))
	
	#create inverted logical array of nas
	invlogi <- rep(TRUE, dim(xframe)[1])
	invlogi[indices] = FALSE
	
	xframe[invlogi, ]
}

stripEmpty <- function (xvec) {
	#remove empty values (NAs, empty string) from vector
	xvec <- xvec[!is.na(xvec)]	#remove NAs
	xvec <- xvec[xvec != ""]		#remove empty strings
	xvec
}

stripClass <- function (x) {
	#remove the class attribute
	`attr<-`(x, "class", NULL)
}

toArray <- function (mylist) {
	## convert list of vectors to an array
	t(array(unlist(mylist), dim=c(length(mylist[[1]]),length(mylist))))
}

trim <- function (string) {
	#remove leading and trailing spaces from a string
	gsub("^\\s+|\\s+$", "", string)
}

tryerrorMsgs <- function (xlist) {
	# return the messages of any element that is a try-error 
	unlist(sapply(xlist, function (x) if (class(x)=="try-error") { stripClass(x) }))
}

updateScenarioWeights <- function(bf, varnamefactor, desiredProp) {
	#return the bf with an updated weightScenario variable
	#based on the factor "varnamefactor" and the desired proportions
	#"desiredProp"
	#eg: children <- updateScenarioWeights(children, "SESBTH", c(0.2,0.3,0.5))
	#prop.table(wtdtable(children$SESBTH, children$weightScenario))
	bf$weightScenario <- factorWeights(bf[[varnamefactor]], desiredProp)
	bf
}

library("Hmisc")
wtdtable <- function (variable, wgts) {
	#eg: wtdtable(people$sex, people$weight)
	#eg: wtdtable(a(children$single)[,1], people$weightBase)
	
	if(length(variable) != length(wgts)) {
		param1Name <- as.character(sys.call())[2]
		param2Name <- as.character(sys.call())[3]
		stop(gettextf("Length of %s != length of weights %s", param1Name, param2Name))
	}
	
	wt <- wtd.table(variable, weights=wgts)
	tbl <- wt$sum.of.weights
	names(tbl) <- wt$x
	
	# wtd.table does not count NAs so we have to do it here
	NAs <- sum(wgts[is.na(variable)])
	if (NAs > 0) {
		#attach NA column to table
		expandedTbl <- as.array(c(tbl,NAs))
		names(expandedTbl) <- c(names(tbl), NA)
		tbl <- expandedTbl
	}
	
	#NB: cast to table because wtd.table doesn't do this
	#but table does and we want wtdtable to act like table
	#so when it is passed to the data.frame command it 
	#works properly
	as.table(tbl)
}

wtdtablecols <- function(mx, weights = rep(1,nrow(mx)), addVariableName = FALSE) {
	#produces a weighted frequency distribution for each column 
	#of the matrix mx and returns them altogether in one table
	#each column can have a different set of categories 
	#(ie: frequency "buckets")
	#if paramater weights is unspecified, a default weight 
	#of 1 is used for each row
	#if addVariableName = TRUE, then the columns will be given the name of mx
	#
	#examples:
	#
	#mx <- matrix(c(8,2,2,2,8,2,3,2,3,2,2,4,8,2,3,4,2,2,4,3),nrow=4,ncol=5)
	#wtdtablecols(mx)
	#wtdtablecols(children$o.single, children$weight)
	
	if(nrow(mx) != length(weights)) {
		param1Name <- as.character(sys.call())[2]
		stop(gettextf("Number of rows in %s != length of weights", param1Name))
	}
	
	# if no column names, number them off
	if (is.null(dimnames(mx)[[COL]])) {
		dimnames(mx)[[COL]] <- seq(dim(mx)[COL])
	}
	
	# get the total set of categories (ie: frequency buckets)
	cats <- as.numeric(names(table(mx)))
	
	# get freqs for each column of mx
	freqs <- apply(mx, COL, function (x) { wtdtable(x,weights)})
	
	if (mode(freqs)=="list") {
		# if its a list it means that the set of cats between
		# columns is not consistent so we need to combine all 
		# the freqs together, joining into cats 
		freqs <- data.frame(
				lapply(freqs, 
						function (x)	{ 
							merge(cats, x, by = 1, all.x=TRUE)$Freq 
						}
				), row.names = cats, check.names = FALSE
		)
	}
	
	# transponse  
	tfreqs <- t(freqs)
	
	# add variable name
	if (addVariableName) {
		firstParamName <- as.character(sys.call())[2] 
		names(dimnames(tfreqs))[2] <- firstParamName
	}
	
	tfreqs
}

wtdmeancols <- function (mx, wgts, by=NULL) {
	#calculates the weighted mean for each column of the matrix
	#optionally grouping by another (equal length) variable
	#	mx <- children$o.gptotvis
	#	wgts <- children$weight
	#	by <- children$z1gender
	# wtdmeancols(children$o.gptotvis, children$weight, children$z1gender)
	# wtdmeancols(children$o.gptotvis, children$weight)
	if (is.null(by)) {
		t(t(colSums(mx * wgts) / sum(wgts)))
	} else {
		weightsGrouped <- aggregate(wgts, by = list(by), FUN = sum)$x
		
		result <- t(apply(mx, COL, function (x) { 
							aggregate(x * wgts, by = list(by), FUN = sum)$x / weightsGrouped
						}))
		dimnames(result)[[COL]] <- sort(unique(by))	
		result
	}
}

lblmeancols <- function (xframe, logiset = NULL, varname, wgtsname, grpbycoding = NULL) {
	#calculates the mean of each column (ie: wtdmeancols) of xframe[[varname]]
	#and labels the result with a meta attribute and names the columns
	#If logiset is not null, then the xframe is firstly subsetted and will
	#only include those obs that have indexed with a TRUE value in the logiset
	#logical vector
	#
	#If grpbycoding is not null, then grouping is applied before calculating
	#the mean.
	# NB: grpbycoding is a named list with varname attribute, eg:
	#  grpbycoding <- c("Other"=1, "Pacific"=2, "Maori"=3)
	#  attr(grpbycoding,"varname") <- "r1stchildethn"
	#
	#eg: xframe <- children
	#    logiset <- childset$females
	#    varname <- "o.gptotvis"
	#	 wgtsname <- "weightScenario"
	#    grpbycoding <- codings$ethnicity
	#
	# lblmeancols(children, childset$males, "o.gptotvis", "weightBase", codings$ethnicity)

	# subset
	xframeset <- if (is.null(logiset)) xframe else subset(xframe, logiset)
	
	if (is.null(grpbycoding)) {
		result <- wtdmeancols(xframeset[[varname]],xframeset[[wgtsname]])
		grpdesc <- NULL
	} else {
		# obtain grpname and desc
		grpname <- attr(grpbycoding,"varname")
		grpdesc <- dict[[grpname]]
		
		result <- wtdmeancols(xframeset[[varname]],xframeset[[wgtsname]],xframeset[[grpname]])
		
		# set column names
		dimnames(result)[[COL]] <- names(grpbycoding)
		names(dimnames(result))[[COL]] <- grpdesc
	}
	
	attr(result, "meta") <- c(varname=varname, grouping=grpdesc, weighting=wgtsname, set=attr(logiset,"desc"))
	result
}