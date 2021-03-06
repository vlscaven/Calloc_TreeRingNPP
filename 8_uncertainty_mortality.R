# -----------------------------------------------------------
# Quantifying the mortality uncertainty in biomass reconstructions for the Valles Caldera
# Cleaned up from https://github.com/alexanderm10/Tree-Rings-and-Biomass/blob/master/Uncertainty_analysis/mortaility_curve.R
# 24 June, 2015
#
# Uses mortailty rates from van Mantgem 2009
#     interior numbers start year 1979 and end year 2011
#     modifies modern stand densities measured in the field 
# -----------------------------------------------------------
# Libraries:
library(ggplot2); library(grid)
library(car)

# Set the random number seed so we always get the same numbers
set.seed(510)

# ------------------------
# Poster Themes
source("poster_theme.R")


# ------------------------
# Load & format data
# ------------------------
ross.trees <- read.csv("raw_input_files/tree_metadata_DOE_plus_valles.csv", na.strings=c("", "NA", "#VALUE!", "*"),header=T)
summary(ross.trees)

# This is the same subsetting proceedure as in "11_uncertainty_comparisons_size.R"
ross.valles <- ross.trees[substr(ross.trees$PlotID,1,1)=="V",c("TreeID", "PlotID", "Species","DBH..cm.", "Density..stems.ha.")]
names(ross.valles)<- c("tree.id", "plot.id", "species", "dbh", "plot.density")
ross.valles$plot.density <- ross.valles$plot.density/10000 # convert density to stems/m2
ross.valles$site <- as.factor(ifelse(substr(ross.valles$plot.id,1,2)=="VU", "VUF", "VLF"))
ross.valles$year <- 2012
ross.valles <- droplevels(ross.valles)
summary(ross.valles)


# Also adding in the raw calculations for Valles density just in case
dens.adj <- data.frame(plot.id      = c("VUA", "VUB", "VLA", "VLB"),
                       trees.plot   = c(   64,   112,    85,    56), # in trees
                       trees.sample = c(   50,    51,    50,    50), # in trees
                       plot.area    = c(24*24, 24*24, 12*12, 26*24)) # in m2
dens.adj$plot.density  <- dens.adj$trees.plot/dens.adj$plot.area # in trees/m2
dens.adj$p.sample <- dens.adj$trees.sample/dens.adj$trees.plot
dens.adj
# ------------------------

# ------------------------
# Defining the mortality parameters from van Mantgem 2009
# M. Alexander got mean & SD by emailing van Mantgem directly
# ASSUMPTION: constant mortality rate prior to where the van Mantgem paper reports the change in rate
# ------------------------
start.yr.vm = 1979 # First year for which the increasing mortality rate is valid
start.yr = 1905    # First year for our study
end.yr = 2011      # Last year in our study

# ---------------
# Define an randomly distributed mortality rate & distribution of the rate of change
# ---------------
n.samps <- 500 # number of samples we want to run
start.m <- rnorm(n.samps, mean=0.4843, sd= 0.2823) # initial mortality rate in 1979
rate.m  <- rnorm(n.samps, mean= 0.024, sd= 0.009*sqrt(9)) # Paper gives SE = 0.009, n=9

# Getting rid of negative mortality rates because we want to assume we're getting recuitment right
# NOTE: not throwing them out entirely, but changing them to 0 to so that we're not shifting the mean 
#       rate quite so highly up
start.m[start.m<0] <- 0 
rate.m[rate.m<0]   <- 0 

# This will be data frame with bootstrapped mortality rates (columns) for a given year (rows)
mort.rate <- data.frame(array(dim=c(length(start.yr:end.yr), length(start.m))))
row.names(mort.rate) <- start.yr:end.yr

i.start <- which(as.numeric(row.names(mort.rate))==start.yr.vm)+1
for(j in 1:ncol(mort.rate)){ # Each column gets run independently
	# mort.pull <- sample(rate.m, size=1, replace=T)
	mort.start <- sample(start.m, size=1, replace=T)
	mort.rate[,j] <- mort.start

	for(i in i.start:nrow(mort.rate)){
		mort.rate[i,j] <- mort.rate[i-1,j] + mort.rate[i-1,j]*sample(rate.m, size=1, replace=T)
	}
  # for(i in 1:nrow(mort.rate)){ # Years
    # if(as.numeric(row.names(mort.rate)[i])<=start.yr.vm){ 
      # # a normally-distributed morality rate with constant mean if it's before the van Mantgem start year
      # mort.rate[i,j] = mort.start
    # } else {
      # # If we're in the time range for van Mantgem, the mortality rate is increasing through time
      # # Here we add the normally distributed rate of change to the previous year's rate
      # mort.rate[i,j] <- mort.rate[i-1,j] + mort.rate[i-1,j]*sample(rate.m, size=1, replace=T)
    # }
  # }
}
mort.rate <- mort.rate[sort(row.names(mort.rate), decreasing=T),] # sort the data so most recent is first
summary(t(mort.rate))

# plot(mort.rate[,1]~as.numeric(row.names(mort.rate)), ylim=range(mort.rate, na.rm=T), type="l")
# for(j in 2:25){
	# lines(mort.rate[,j]~as.numeric(row.names(mort.rate)))
# }
# ---------------
# ------------------------


# ------------------------
# Applying the mortality rates to our densities
# ------------------------
# creating a base data frame for density in each year
density.time <- array(dim=c(length(end.yr:start.yr), length(unique(dens.adj$plot.id)),n.samps))
dimnames(density.time)[[1]] <- end.yr:start.yr
dimnames(density.time)[[2]] <- dens.adj$plot.id

for(p in 1:length(dimnames(density.time)[[2]])){
	density.time[,p,] <- dens.adj[p, "plot.density"]
}

# working backwards in time with our density calculation
for(j in 1:dim(density.time)[2]){ # go for each plot
  for(i in 2:nrow(density.time)){ # we know modern density, so start after that
	density.time[i,j,1] <- density.time[i-1,j,1] # Make the first one the scenario with no mortality. i.e.: if our field-based densities held true for all time.
	for(n in 2:dim(mort.rate)[2]){
	  # multiply the density by mortality rate matrix
      density.time[i,j,n] <- density.time[i-1,j,n] + density.time[i-1,j,n]* mort.rate[i,n]/100
    }
  }
}
summary(density.time[,,1])
summary(density.time[,,2])
# ------------------------
plot(density.time[,4,2]~as.numeric(dimnames(density.time)[[1]]), type="l", col="red")
lines(density.time[,4,1]~as.numeric(dimnames(density.time)[[1]]), col="black")
# ------------------------
# re-running the allometry calculations with the mortality-adjusted densities
# see "5_post_GF_TRW_to_biomass.R" for original workflow
# ------------------------
# open up the gapfilled diameter reconstruction & subset only the Valles & the time period of interest
g.filled.diam <- read.csv("processed_data/GapFilling_DBHrecon_ALL.csv", header=T, row.names=1)
g.filled.diam <- g.filled.diam[,which(substr(names(g.filled.diam),1,1)=="V")]
g.filled.diam[g.filled.diam==0] <- 1e-6 # dbh=0 causes problems, so we're going to make those a very small number
# subset only the years we're working with for the density
g.filled.diam <- g.filled.diam[which(as.numeric(row.names(g.filled.diam))>=start.yr & as.numeric(row.names(g.filled.diam))<=end.yr ),]
dim(g.filled.diam)

# load the allometries list
load("processed_data/allometries_list.Rdata")

# Load the tree metadata & subset it to match our diameter series
tree.data <- read.csv("processed_data/TreeData.csv", header=T)
trees.use <- tree.data[tree.data$TreeID %in% names(g.filled.diam),] 
summary(trees.use)

# Find out what species we don't have allometries for that need to be renames
unique(trees.use$Species)[!(unique(trees.use$Species) %in% names(allometries))]
trees.use$spp.allom <- recode(trees.use$Species, " 'PIEN'='picea.sp'")
summary(trees.use)


plots <- unique(trees.use$PlotID) # find out what plots we're looping through

# making the generalized allometry function to run
# log(AGB) = mu0 + mu1*log(DBH) --equaton form of PECAN allometrics
allom.eq <- function(mu0, mu1, DBH) { exp(mu0 + mu1 * log(DBH) )}


# Making the array for the out densities; NOTE: here the 3rd dimension is based off our density iterations NOT allometry iterations
bm.array <- array(NA, dim=c(nrow(g.filled.diam), ncol(g.filled.diam), dim(density.time)[3]))
dimnames(bm.array)[[1]] <- row.names(g.filled.diam)  #CRR Added
dimnames(bm.array)[[2]] <- names(g.filled.diam)

# making a blank allometry data frame
allom.temp <- g.filled.diam
allom.temp[,] <- NA  

# Species loop for calculating tree biomass off of the mean equation
# NOTE: no allometry iterations loop since we just want th eman
for(j in unique(trees.use$spp.allom)){
  cols <- which(names(g.filled.diam) %in% trees.use[trees.use$spp.allom==j, "TreeID"])

  # Pulling coefficients from the randomly pulled estimates from Pecan; 
  # Need to use Bg0 because the heierarchical means were being weird
  mu0=mean(allometries[[j]][,"Bg0"])
  mu1=mean(allometries[[j]][,"Bg1"])
  allom.temp[,cols] <- allom.eq(mu0=mu0, mu1 = mu1, DBH = g.filled.diam[,cols])
}

# summing to the plot level
allom.temp[is.na(allom.temp)] <- 0

# getting new biomass estimates in kg/m2 for each tree
# run each tree through each layer of density.time
for(t in 1:ncol(allom.temp)){ 
  for(i in 1:dim(density.time)[3]){
	plotID <- paste(tree.data[tree.data$TreeID==names(allom.temp)[t], "PlotID"]) # figure out which plot we're workign with
	plot.index <- which(dimnames(density.time)[[2]]==plotID) # figure out which column we want to be pulling from
     bm.array[,t,i] <- allom.temp[,t]*density.time[,plot.index,i]
  }
}
dim(bm.array)
dim(density.time)

# NOTE: bm.array[,,1] is the no-mortality adjusted scenario
summary(bm.array[,1:10,1])
summary(bm.array[,1:10,2])


# ------------------------

# ------------------------
## Aggregating directly to the site level similar to how we did with allometry uncertainty
# New: going through the plot first
# ------------------------
# -------------
# Starting at the plot level
# -------------
plots <- unique(ross.valles$plot.id)
plots

bm.plot <- array(dim=c(dim(bm.array)[1], length(plots), dim(bm.array)[3])) # years x plots x mortality iterations
dimnames(bm.plot)[[1]] <- row.names(g.filled.diam)
dimnames(bm.plot)[[2]] <- plots

for(p in 1:length(plots)){
	cols <- which(dimnames(bm.array)[[2]] %in% ross.valles[ross.valles$plot.id==plots[p], "tree.id"])
	bm.plot[,p,] <- apply(bm.array[,cols,],c(1,3), mean, na.rm=T)
}
summary(bm.plot[,,1]) # 1st value of 3rd dimension still our reference point
summary(bm.plot[,,2]) 
# -------------

# -------------
# Aggregating to the site level
# -------------
sites <- unique(substr(dimnames(bm.plot)[[2]], 1, 2))

# set up the blank array where things will be written
bm.site <- array(dim=c(dim(bm.array)[1], length(sites), 4)) # years x plots x (mean, sd, ci.low, ci.hi)
dimnames(bm.site)[[1]] <- row.names(g.filled.diam)
dimnames(bm.site)[[2]] <- paste0(sites, "F")
dimnames(bm.site)[[3]] <- c("mean", "sd", "ci.lo", "ci.hi")

for(s in 1:length(sites)){ 
  # figure out which trees belong to which site
  cols <- which(substr(dimnames(bm.plot)[[2]],1,2) == sites[s])

  # Finding the mean site bioass while preserving the density iterations
	# Here we condense to 2 dimensions; the 1st column will be our reference point
  bm.temp <- apply(bm.plot[,cols,],c(1,3), mean, na.rm=T) 

	# do the calculations to find the density-based mean & CI
	bm.site[,s,1] <- bm.temp[,1]
	bm.site[,s,2] <- apply(bm.temp, 1, sd)
	bm.site[,s,3] <- apply(bm.temp[,2:ncol(bm.temp)], 1, quantile, 0.025, na.rm=T)
	bm.site[,s,4] <- apply(bm.temp[,2:ncol(bm.temp)], 1, quantile, 0.975, na.rm=T)
}
summary(bm.site[,,1])

uncert.mort <- stack(data.frame(bm.site[,,1]))[,c(2,1)]
names(uncert.mort) <- c("SiteID", "BM.Mean") # NOTE!! BM.MEAN = no-mortality reference point
uncert.mort$Year <- as.numeric(dimnames(bm.site)[[1]])
uncert.mort$Mort.SD <- stack(data.frame(bm.site[,,2]))[,1]
uncert.mort$Mort.CI.lo <- stack(data.frame(bm.site[,,3]))[,1]
uncert.mort$Mort.CI.hi <- stack(data.frame(bm.site[,,4]))[,1]
uncert.mort$Site <- recode(uncert.mort$SiteID, "'VUF'='1';'VLF'='2'")
levels(uncert.mort$Site) <- c("Upper", "Lower")
summary(uncert.mort)

#Poster Figure
# pdf("figures/Uncertainty_Mortality_TimeSeries.pdf", width= 13, height= 8.5)
# ggplot(uncert.mort) +
	# geom_ribbon(aes(x=Year, ymin=Mort.CI.lo, ymax=Mort.CI.hi, fill=Site), alpha=0.4) +
	# geom_line(aes(x=Year, y=BM.Mean, color=Site), size=1.5) +
	# labs(x="Year", y=expression(bold(paste("Biomass (kg m" ^ "-2 ", ")"))), title="Mortality Uncertainty") +
  # theme(axis.ticks.length = unit(-0.25, "cm"),
        # axis.ticks.margin = unit(0.5, "cm")) +
  # # add time slice lines
  # geom_vline(xintercept=c(1980, 1995, 2011), linetype="dotted",size=1.5) +
	# poster.theme1 #theme.bw()
# dev.off()

#Publication Figure
pdf("figures/Uncertainty_Mortality_TimeSeries.pdf", width= 13, height= 8.5)
ggplot(uncert.mort) +
	geom_ribbon(aes(x=Year, ymin=Mort.CI.lo, ymax=Mort.CI.hi, fill=Site), alpha=0.4) +
	geom_line(aes(x=Year, y=BM.Mean, color=Site), size=1.5) +
	labs(x="Year", y=expression(paste("Biomass (kg m" ^ "-2 ", ")")), title="Mortality Uncertainty") +
  theme(axis.ticks.length = unit(-0.25, "cm"),
        axis.ticks.margin = unit(0.5, "cm")) +
  # add time slice lines
  geom_vline(xintercept=c(1980, 1995, 2011), linetype="dotted",size=1) +
  
  	# General Formatting  
	theme(legend.position=c(0.15,0.85)) + 
	theme(axis.line=element_line(color="black", size=0.5), panel.grid.major=element_blank(), panel.grid.minor= element_blank(), panel.border= element_blank(), panel.background= element_blank(), axis.text.x=element_text(angle=0, color="black", size=rel(1.5)), axis.text.y=element_text(color="black", size=rel(1.5)), axis.title.x=element_text(vjust=-0.5),  axis.title.y=element_text(size=rel(1.5), vjust=1), plot.margin=unit(c(0.1,0.5,0.5,0.1), "lines")) +

  theme(strip.text=element_text(size=rel(1.5)))+
  theme(axis.ticks.length = unit(-0.25, "cm"),
        axis.ticks.margin = unit(0.5, "cm"))

dev.off()

save(uncert.mort, file="processed_data/valles_mortality_uncertainty.Rdata")
# ------------------------
