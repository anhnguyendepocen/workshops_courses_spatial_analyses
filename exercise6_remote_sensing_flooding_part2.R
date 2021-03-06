####################################    Flood Mapping Analyses   #######################################
############################  Analyze and map flooding from RITA hurricane  #######################################
#This script performs analyses for the Exercise 6 of the Short Course using reflectance data derived from MODIS.
#The goal is to map flooding from RITA using various reflectance bands from Remote Sensing platforms.
#Additional data is provided including FEMA flood region. 
#
#AUTHORS: Benoit Parmentier                                             
#DATE CREATED: 03/13/2018 
#DATE MODIFIED: 04/01/2018
#Version: 1
#PROJECT: SESYNC and AAG 2018 workshop/Short Course preparation
#TO DO:
#
#COMMIT: setting up input data
#
#################################################################################################

###Loading R library and packages                                                      

library(sp) # spatial/geographfic objects and functions
library(rgdal) #GDAL/OGR binding for R with functionalities
library(spdep) #spatial analyses operations, functions etc.
library(gtools) # contains mixsort and other useful functions
library(maptools) # tools to manipulate spatial data
library(parallel) # parallel computation, part of base package no
library(rasterVis) # raster visualization operations
library(raster) # raster functionalities
library(forecast) #ARIMA forecasting
library(xts) #extension for time series object and analyses
library(zoo) # time series object and analysis
library(lubridate) # dates functionality
library(colorRamps) #contains matlab.like color palette
library(rgeos) #contains topological operations
library(sphet) #contains spreg, spatial regression modeling
library(BMS) #contains hex2bin and bin2hex, Bayesian methods
library(bitops) # function for bitwise operations
library(foreign) # import datasets from SAS, spss, stata and other sources
#library(gdata) #read xls, dbf etc., not recently updated but useful
library(classInt) #methods to generate class limits
library(plyr) #data wrangling: various operations for splitting, combining data
#library(gstat) #spatial interpolation and kriging methods
library(readxl) #functionalities to read in excel type data
library(psych) #pca/eigenvector decomposition functionalities
library(sf)
library(plotrix) #various graphic functions e.g. draw.circle
library(nnet)
library(rpart)
library(e1071)
library(caret)

###### Functions used in this script

create_dir_fun <- function(outDir,out_suffix=NULL){
  #if out_suffix is not null then append out_suffix string
  if(!is.null(out_suffix)){
    out_name <- paste("output_",out_suffix,sep="")
    outDir <- file.path(outDir,out_name)
  }
  #create if does not exists
  if(!file.exists(outDir)){
    dir.create(outDir)
  }
  return(outDir)
}

#Used to load RData object saved within the functions produced.
load_obj <- function(f){
  env <- new.env()
  nm <- load(f, env)[1]
  env[[nm]]
}

#####  Parameters and argument set up ###########

in_dir_var <- "/nfs/bparmentier-data/Data/workshop_spatial/sesync2018_workshop/Exercise_6/data/"
out_dir <- "/nfs/bparmentier-data/Data/workshop_spatial/sesync2018_workshop//Exercise_6/outputs"

#region coordinate reference system
#http://spatialreference.org/ref/epsg/nad83-texas-state-mapping-system/proj4/
CRS_reg <- "+proj=lcc +lat_1=27.41666666666667 +lat_2=34.91666666666666 +lat_0=31.16666666666667 +lon_0=-100 +x_0=1000000 +y_0=1000000 +ellps=GRS80 +datum=NAD83 +units=m +no_defs" 
file_format <- ".tif" #PARAM5
NA_flag_val <- -9999 #PARAM6
out_suffix <-"exercise6_03312018" #output suffix for the files and ouptu folder #PARAM 8
create_out_dir_param=TRUE #PARAM9

#ARG9
#local raster name defining resolution, extent
infile_RITA_reflectance_date2 <- "mosaiced_MOD09A1_A2005273__006_reflectance_masked_RITA_reg_1km.tif"
infile_reg_outline <- "new_strata_rita_10282017.shp" # Region outline and FEMA zones
infile_modis_bands_information <- "df_modis_band_info.txt" # MOD09 bands information.
nlcd_2006_filename <- "nlcd_2006_RITA.tif" # NLCD2006 Land cover data aggregated at ~ 1km.

infilename_class1 <- "class1.shp" # Ground truth data for class 1
infilename_class2 <- "class2.shp" # Ground truth data for class 2
infilename_class3 <- "class3.shp" # Ground truth data for class 3

#class1_sites.shp

###########################  START SCRIPT  ##############################

####### SET UP OUTPUT DIRECTORY #######

## First create an output directory

if(is.null(out_dir)){
  out_dir <- dirname(in_dir) #output will be created in the input dir
}

out_suffix_s <- out_suffix #can modify name of output suffix
if(create_out_dir_param==TRUE){
  out_dir <- create_dir_fun(out_dir,out_suffix_s)
  setwd(out_dir)
}else{
  setwd(out_dir) #use previoulsy defined directory
}

#####################################
##### PART I: DISPLAY AND EXPLORE DATA ##############

#### MOD09 raster image after hurricane Rita
r_after <- brick(file.path(in_dir_var,infile_RITA_reflectance_date2))

## Read band information since it is more informative!!
df_modis_band_info <- read.table(file.path(in_dir_var,infile_modis_bands_information),
                                 sep=",",
                                 stringsAsFactors = F)
print(df_modis_band_info)
df_modis_band_info$band_number <- c(3,4,1,2,5,6,7)
write.table(df_modis_band_info,file.path(in_dir_var,infile_modis_bands_information),
            sep=",")

band_refl_order <- df_modis_band_info$band_number

names(r_after) <- df_modis_band_info$band_name

## Use subset instead of $ if you want to wrap code into function
r_after_MNDWI <- (subset(r_after,"Green") - subset(r_after,"SWIR2")) / (subset(r_after,"Green") + subset(r_after,"SWIR2"))
plot(r_after_MNDWI,zlim=c(-1,1))
r_after_NDVI <- (subset(r_after,"NIR") - subset(r_after,"Red")) / (subset(r_after,"NIR") + subset(r_after,"Red"))
plot(r_after_NDVI)

data_type_str <- dataType(r_after_NDVI)

NAvalue(r_after_NDVI) <- NA_flag_val
out_filename <- paste("ndvi_post_Rita","_",out_suffix,file_format,sep="")
out_filename <- file.path(out_dir,out_filename)
writeRaster(r_after_NDVI,
            filename=out_filename,
            datatype=data_type_str,
            overwrite=T)

NAvalue(r_after_MNDWI) <- NA_flag_val
out_filename <- paste("mndwi_post_Rita","_",out_suffix,file_format,sep="")
out_filename <- file.path(out_dir,out_filename)
writeRaster(r_after_MNDWI,
            filename=out_filename,
            datatype=data_type_str,
            overwrite=T)

#training_data_sf <- st_read("training1.shp")
#1) vegetation and other (small water fraction)
#2) Flooded vegetation
#3) Flooded area, or water (lake etc)

class1_data_sf <- st_read(file.path(in_dir_var,"class1_sites.shp"))
class2_data_sf <- st_read(file.path(in_dir_var,"class2_sites.shp"))
class3_data_sf <- st_read(file.path(in_dir_var,"class3_sites.shp"))

### combine object, note they should be in the same projection system
class_data_sf <- rbind(class1_data_sf,class2_data_sf,class3_data_sf)
class_data_sf$poly_ID <- 1:nrow(class_data_sf) #unique ID for each polygon
nrow(class_data_sf) # 23 different polygons used at ground truth data
class_data_sp <- as(class_data_sf,"Spatial")

r_x <- init(r_after,"x") #raster with coordinates x
r_y <- init(r_after,"x") #raster with coordiates y

r_stack <- stack(r_x,r_y,r_after,r_after_NDVI,r_after_MNDWI)
names(r_stack) <- c("x","y","Red","NIR","Blue","Green","SWIR1","SWIR2","SWIR3","NDVI","MNDWI")
pixels_extracted_df <- extract(r_stack,class_data_sp,df=T)

dim(pixels_extracted_df) #We have 1547 pixels extracted
class_data_df <- class_data_sf
st_geometry(class_data_df) <- NULL #this will coerce the sf object into a data.frame

pixels_df <- merge(pixels_extracted_df,class_data_df,by.x="ID",by.y="poly_ID")

head(pixels_df)
table(pixels_df$class_ID) # count by class of pixels ground truth data

######## Examining sites data used for the classification

#Water
x_range <- range(pixels_df$Green,na.rm=T)
y_range <- range(pixels_df$NIR,na.rm=T)

###Add legend?
plot(NIR~Green,xlim=x_range,ylim=y_range,cex=0.2,col="blue",subset(pixels_df,class_ID==1))
points(NIR~Green,col="green",cex=0.2,subset(pixels_df,class_ID==2))
points(NIR~Green,col="red",cex=0.2,subset(pixels_df,class_ID==3))
names_vals <- c("water class 1","water class 2","water class 3")
legend("topleft",legend=names_vals,
       pt.cex=0.7,cex=0.7,col=c("blue","green","red"),
       pch=20, #add circle symbol to line
       bty="n")

## Let's use a palette that reflects wetness or level of water 
col_palette <- c("green","blue","darkblue")
plot(NDVI ~ MNDWI,
     xlim=c(-1,1),ylim=c(-1,1),
     cex=0.2,
     col=col_palette[1],
     subset(pixels_df,class_ID==1))

points(NDVI ~ MNDWI,
       cex=0.2,
       col=col_palette[2],
       subset(pixels_df,class_ID==2))

points(NDVI ~ MNDWI,
       cex=0.2,
       col=col_palette[3],
       subset(pixels_df,class_ID==3))

names_vals <- c("vegetation","wetland","water")
legend("topright",legend=names_vals,
       pt.cex=0.7,cex=0.7,col=col_palette,
       pch=20, #add circle symbol to line
       bty="n")

histogram(r_after)

pixels_df$class_ID <- factor(pixels_df$class_ID,
                    levels = c(1,2,3),
                    labels = names_vals)

boxplot(MNDWI~class_ID,
        pixels_df,
        xlab="category",
        main="Boxplot for MNDWI per class")

###############################################
##### PART II: Split training and testing ##############

##let's keep 30% of data for testing for each class

pixels_df$pix_ID <- 1:nrow(pixels_df)
prop <- 0.3
table(pixels_df$class_ID)
set.seed(100) ## set random seed for reproducibility

### This is for one class:
##Better as a function but we use a loop for clarity here:

list_data_df <- vector("list",length=3)
level_labels <- names_vals

for(i in 1:3){
  data_df <- subset(pixels_df,class_ID==level_labels[i])
  data_df$pix_id <- 1:nrow(data_df)
  indices <- as.vector(createDataPartition(data_df$pix_ID,p=0.7,list=F))
  data_df$training <-  as.numeric(data_df$pix_id %in% indices)
  list_data_df[[i]] <- data_df
}

data_df <- do.call(rbind,list_data_df)

dim(data_df)
head(data_df)

data_training <- subset(data_df,training==1)

###############################################
##### PART III: Generate classification using CART and SVM ##############

############### Using Classification and Regression Tree model (CART) #########

## Fit model using training data for CART
mod_rpart <- rpart(class_ID ~ Red + NIR + Blue + Green + SWIR1 + SWIR2 + SWIR3,
                   method="class", 
                   data=data_training)

# Plot the fitted  classification tree
plot(mod_rpart, uniform=TRUE, main="Classification Tree")
text(mod_rpart, cex=.8)

# Now predict the subset data based on the model; prediction for entire area takes longer time
raster_out_filename <- paste0("r_predicted_rpart_",out_suffix,file_format)
r_predicted_rpart <- predict(r_stack,mod_rpart, 
                             type='class',
                             filename=raster_out_filename,
                             progress = 'text',
                             overwrite=T)

plot(r_predicted_rpart)
r_predicted_rpart <- ratify(r_predicted_rpart)
rat <- levels(r_predicted_rpart)[[1]]
rat$legend <- c("vegetation","wetland","water")
levels(r_predicted_rpart) <- rat
levelplot(r_predicted_rpart, maxpixels = 1e6,
          col.regions = c("green","blue","darkblue"),
          scales=list(draw=FALSE),
          main = "Classification Tree")

############### Using Support Vector Machine #########

## set class_ID as factor to generate classification

mod_svm <- svm(class_ID ~ Red +NIR + Blue + Green + SWIR1 + SWIR2 + SWIR3,
               data=data_training,
               method="C-classification",
               kernel="linear") # can be radial

summary(mod_svm)

# Now predict the subset data based on the model; prediction for entire area takes longer time
raster_outfilename <- paste0("r_predicted_svm_",out_suffix,file_format)
r_predicted_svm <- predict(r_stack, mod_svm,
                           progress = 'text',
                           filename=raster_outfilename,
                           overwrite=T)

plot(r_predicted_svm)
histogram(r_predicted_svm)
r_predicted_svm <- ratify(r_predicted_svm)
rat <- levels(r_predicted_svm)[[1]]
rat$legend <- c("vegetation","wetland","water")
levels(r_predicted_svm) <- rat
levelplot(r_predicted_svm, maxpixels = 1e6,
          col.regions = c("green","blue","darkblue"),
          scales=list(draw=FALSE),
          main = "SVM classification")

###############################################
##### PART IV: Compare methods for the performance ##############

dim(data_df) # full dataset, let's use data points for testing
#omit values that contain NA, because may be problematic with SVM.
data_testing <- na.omit(subset(data_df,training==0)) 
dim(data_testing)

#### Predict on testing data using rpart model fitted with training data
testing_rpart <- predict(mod_rpart, data_testing,type='class')
#### Predict on testing data using SVM model fitted with training data
testing_svm <- predict(mod_svm,data_testing, type='class')

## Predicted classes:
table(testing_svm)

#### Generate confusion matrix to assess the performance of the model

tb_rpart <- table(testing_rpart,data_testing$class_ID)
tb_svm <- table(testing_svm,data_testing$class_ID)

#testing_rpart: map prediction in the rows
#data_test$class_ID: ground truth data in the columns
#http://spatial-analyst.net/ILWIS/htm/ilwismen/confusion_matrix.htm
#Producer accuracy: it is the fraction of correctly classified pixels with regard to all pixels 
#of that ground truth class. 

table(testing_rpart) #classification, map results
table(data_testing$class_ID) #reference, ground truth in columns


tb_rpart[1]/sum(tb_rpart[,1]) #producer accuracy
tb_svm[1]/sum(tb_svm[,1]) #producer accuracy

#overall accuracy for svm
sum(diag(tb_svm))/sum(table(testing_svm))
#overall accuracy for rpart
sum(diag(tb_rpart))/sum(table(testing_rpart))

#Generate more accuracy measurements from CARET
accuracy_info_svm <- confusionMatrix(testing_svm,data_testing$class_ID, positive = NULL)
accuracy_info_rpart <- confusionMatrix(testing_rpart,data_testing$class_ID, positive = NULL)

accuracy_info_rpart$overall
accuracy_info_svm$overall

#### write out the results:
write.table(accuracy_info_rpart$table,"confusion_matrix_rpart.txt",sep=",")
write.table(accuracy_info_svm$table,"confusion_matrix_svm.txt",sep=",")

############################ End of Script ###################################

