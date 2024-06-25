# Libraries needed to run the code:
# For reading and combining the csv files:
library(data.table)
library(readr)
# To rearrange the data table:
library(stringr)
library(tidyverse)

# choose working directory where the subfolders containing data tables generated with ImageJ are:
work_folder <- choose.dir() 
setwd(work_folder)

# take all the csv files in the working directory, searching in the subfolders too
# make a list of all csv files and create a data frame containing morphometry and intensities
all_files <- list.files(path = work_folder, recursive = TRUE, full.names = TRUE)

# Filter to include only CSV files and exclude those with "RRQuant-analysis" in their filenames
file_list <- all_files[grepl("\\.csv$", all_files, ignore.case = TRUE) & !grepl("RRQuant-analysis", all_files, ignore.case = FALSE)]

csv_list <- lapply(file_list, function(file) {
  data <- read.csv(file)
  data$filename <- basename(file)
  return(data)
})

merged_csv <- bind_rows(csv_list)

# Add columns based on filename to later be able to sort the data based on the condition or the replicate:
merged_csv[c('Condition', 'Staining', 'Replicate','Info')] <- str_split_fixed(merged_csv$filename, '--', 4)
merged_csv$Sample <- paste0(merged_csv$Condition, "-", merged_csv$Staining, "-", merged_csv$Replicate, "-", merged_csv$Label)
merged_csv$Sample_replicate <- paste0(merged_csv$Condition, "-", merged_csv$Staining, "-", merged_csv$Replicate)
merged_csv$Condition_staining <- paste0(merged_csv$Condition, "-", merged_csv$Staining)
merged_csv$Condition_replicate <- paste0(merged_csv$Condition, "-", merged_csv$Replicate)

merged_csv$RRmean_absolute <- merged_csv$Mean

# 1 row for 1 sample:
merged_bysample <- merged_csv %>%
  group_by(Sample) %>%
  summarise_all(funs(ifelse(all(is.na(.)), NA, first(na.omit(.)))))

# New data table with only the values of interest: 
main_table <- subset(merged_bysample, select = c("Condition", "Staining", "Replicate", "Label", "Sample", "Condition_staining", "Sample_replicate", "Condition_replicate", "PixelCount", "Area", "Perimeter", "GeodesicDiameter", "AverageThickness", "InscrDisc.Radius", "Circularity", "RRmean_absolute","MaxFeretDiam", "MaxFeretDiamAngle", "Tortuosity"))

colnames(main_table)[colnames(main_table) == 'GeodesicDiameter'] <- 'Length'

# add a column to compute the relative staining value of the samples (mean_stained/mean_non stained) 
# mean of the RRmean of non stained samples for non stained samples per Condition:
main_table$RRmean_NS_Condition <- NA
# Calculate and store the mean intensity for non-stained samples for each Condition separately
genotypes <- unique(main_table$Condition_staining)
for (genotype in genotypes) {
# Filter the dataset to include only non-stained samples for the current Condition
  non_stained_data <- main_table[main_table$Staining == "NonStained" & main_table$Condition_staining == genotype, ]
# Calculate the mean intensity for non-stained samples for the current Condition
  mean_intensity <- sum(non_stained_data$RRmean_absolute) / nrow(non_stained_data)
# Add a new column to the original dataset with the calculated mean intensity for the current Condition
  main_table$RRmean_NS_Condition[main_table$Condition_staining == genotype] <- mean_intensity
}

# mean of the RRmean of non stained samples for non stained samples per Condition and replicate:
main_table$RRmean_NS_rep <- NA
replicates <- unique(main_table$Sample_replicate)
for (replicate in replicates) {
# Filter the dataset to include only non-stained samples for the current Condition
  non_stained_data <- main_table[main_table$Staining == "NonStained" & main_table$Sample_replicate == replicate, ]
# Calculate the mean intensity for non-stained samples for the current Condition
  mean_intensity <- sum(non_stained_data$RRmean_absolute) / nrow(non_stained_data)
# Add a new column to the original dataset with the calculated mean intensity for the current Condition
  main_table$RRmean_NS_rep[main_table$Sample_replicate == replicate] <- mean_intensity
}

# Compute the relative staining intensity Stained/non-stained: 
# per Condition:
main_table$RRmean_relative_NS_Condition <- NA
main_table <- main_table %>%
  group_by(Condition) %>%
  mutate(RRmean_NS_Condition = mean(RRmean_NS_Condition[Staining == "NonStained"])) %>%
  mutate(RRmean_relative_NS_Condition = ifelse(Staining == "Stained", RRmean_absolute / RRmean_NS_Condition, NA))
# per replicate:
main_table$RRmean_relative_NS_rep <- NA
main_table <- main_table %>%
  group_by(Condition_replicate) %>%
  mutate(RRmean_NS_rep = mean(RRmean_NS_rep[Staining == "NonStained"])) %>%
  mutate(RRmean_relative_NS_rep = ifelse(Staining == "Stained", RRmean_absolute / RRmean_NS_rep, NA))

#### Save usable data frame as csv file -----------------------------------------------------------------------------------------

## First, all data stained and non stained
# define the file name:
file_name <- paste0("RRQuant-analysis-all_", format(Sys.time(), "%Y-%m-%d_%H%M%S"), ".csv")
print(file_name)
# Combine the working directory and file name to get the full file path
file_path <- file.path(work_folder, file_name)
# Save the CSV file
write.csv(main_table, file = file_path, row.names = FALSE, quote = FALSE)


# Sort out the false objects (small segmented things that are not hypocotyls)
main_table2 <- main_table %>%
  filter(Staining != "NonStained" & PixelCount >= 200) 

data_stained <- subset(main_table2, select= c("Condition", "Replicate", "Condition_replicate", "Sample", "RRmean_absolute", "RRmean_relative_NS_Condition", "RRmean_relative_NS_rep", "PixelCount", "Area", "Perimeter", "Length", "AverageThickness", "InscrDisc.Radius", "Circularity", "MaxFeretDiam", "MaxFeretDiamAngle", "Tortuosity"))

## A second table with only the Stained samples for representation (and use in the RRQuant shiny app) 
# Define the file name
file_name_stained <- paste0("RRQuant-analysis-Stained_", format(Sys.time(), "%Y-%m-%d_%H%M%S"), ".csv")
print(file_name_stained)
# Combine the working directory and file name to get the full file path
file_path <- file.path(work_folder, file_name_stained)
# Save the CSV file
write.csv(data_stained, file = file_path, row.names = FALSE, quote = FALSE)


# ------------------------------ TABLES READY TO USE -------------------------------- #

