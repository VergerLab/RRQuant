///======================MACRO=========================///
macro_name = "RRQuant";
///====================================================///
///File author(s): Stephane Verger======================///

///====================Description=====================///
/* This macro takes as input RGB .tif images of stained 
 * samples and corresponding mask images (see input parameters).
 * It outputs several morphometry measurments on the masks
 * for cell hypocotyl and size, and staining intensity 
 * measurment for ruthenium red under the form of .csv files. 
 * (see measurment and output parameters).
 * For further details see macro_source.
*/
macro_source = "https://github.com/VergerLab/RRQuant";

///=========Input/output file names parameters=========///
// Input paramaters: input files suffixes
RR_suffix = "--img.tif"; //RGB ruthenium red staining image
msk_suffix = "--msk.png"; //Label image from cellpose segmentation

//(###)Smoothing value 

// Measurment parameters (from MorpholibJ):
Int_Measurments = "mean stddev max min median mode skewness kurtosis numberofvoxels volume neighborsmean neighborsstddev neighborsmax neighborsmin neighborsmedian neighborsmode neighborsskewness neighborskurtosis";
Morpho_Measurments = "pixel_count area perimeter circularity euler_number bounding_box centroid equivalent_ellipse ellipse_elong. convexity max._feret oriented_box oriented_box_elong. geodesic tortuosity max._inscribed_disc average_thickness geodesic_elong.";

// Output paramaters: output file suffixes
RRInt_suffix = "--RRstaining.csv"; //MorpholibJ Ruthenium red staining measurment (RGB image is transformed into HSL stacks. S and L images are added and to measure color intensity).
Morpho_suffix = "--Morphometry.csv"; //MorpholibJ "analyze regions" measurment on masks.
//(###)SmoothMorpho_suffix = "--SmoothMorphometry.csv" //MorpholibJ "analyze regions" measurment on smoothed masks (used to calculate sample "roughness".

///====================================================///
///====================================================///
///====================================================///

print("\\Clear");

//Select directory
dir = getDirectory("Choose a directory");
dir_name = File.getName(dir);
dir_list = getFileList(dir);

setBatchMode("hide");

//Generate log file for record
log_file_name = "Log_" + dir_name + "_" + macro_name + ".txt";
fLog = File.open(dir + File.separator + log_file_name);
print(fLog, "Files processed with the macro " + macro_name + ".ijm\n(" + macro_source + ")\n\n");
print(fLog, "Directory: " + dir + "\n\nFiles processed:");
File.close(fLog);

s = 0;
//Loop on all the folder in the directory
for (i=0; i<dir_list.length; i++){
	
	//Select image series to process
	if(endsWith (dir_list[i], RR_suffix)){
		print("file_path", dir + dir_list[i]);
			
		//count samples analyzed
		s++;
		
		//Extract generic name and path of the image serie
		File_name = substring(dir_list[i], 0, indexOf(dir_list[i], RR_suffix));
		
		//Define input and output filenames
		RR_Image = File_name + RR_suffix;
		msk_Image = File_name + msk_suffix;
		RR_Results = File_name + RRInt_suffix;
		Morpho_Results = File_name + Morpho_suffix;
		RRInt_Image = "RRIntensity";
		lbl_Image = File_name + "--msk-lbl";
		//(###)SmoothMorpho_Results = File_name + SmoothMorpho_suffix;
		//(###)Smooth_Image = "SmoothMask";
		
		//Write to log txt file
		File.append("- Sample number: " + s + "\n" + File_name, dir + File.separator + log_file_name);
		print("Sample: " + File_name);
		print("--> Opening input images");
				
		//Open RGB image
		open(dir + RR_Image);
		
		//Get pixel size for label image based on RGB image
		selectImage(RR_Image);
		getPixelSize(unit, pixelWidth, pixelHeight);
		
		//Convert to HSB stack and split channels
		run("HSB Stack");
		run("Stack to Images");
		
		//Invert "brightness" image, add to "Saturation" image and close "Hue".
		selectImage("Brightness");
		run("Invert");
		imageCalculator("Add create 32-bit", "Saturation","Brightness");
		selectImage("Hue");
		close();
		selectImage("Result of Saturation");
		rename(RRInt_Image);
			    
		//Open lmask image
		open(dir + msk_Image);
		
		//(###)SmoothMorpho_Results = File_name + SmoothMorpho_suffix;Duplication and smoothing
		
		//Connected componnent labeling and apply pixel size
		selectImage(msk_Image);
		run("Connected Components Labeling", "connectivity=4 type=[16 bits]");
		selectImage(lbl_Image);
		setVoxelSize(pixelWidth, pixelWidth, "1", unit);
				
		//Quantifications
		print("--> Measurments:");
		
		//Measure, save and close RR intensity
		print("    --> RR intensity");
		run("Intensity Measurements 2D/3D", "input=" + RRInt_Image + " labels=" + lbl_Image + " " + Int_Measurments);
		saveAs("Results", dir + RR_Results);
		selectWindow(RR_Results);
		run("Close");
		
		//Measure, save and close hypo moprhometrics
		print("    --> Morphometry");
		selectImage(lbl_Image);
		run("Analyze Regions", Morpho_Measurments);
		saveAs("Results", dir + Morpho_Results);
		selectWindow(Morpho_Results);
		run("Close");
		
		//(###)Measure, save and close Smooth hypo moprhometrics
		//(###)print("    --> Smooth Morphometry");
		//(###)selectImage(//_Image);
		//(###)run("Analyze Regions", Morpho_Measurments);
		//(###)saveAs("Results", dir + //);
		//(###)selectWindow(//);
		//(###)run("Close");
				
		//Close images
		close("*");
		
		//Write to log, input files used, output file generated, time and date
		File.append("\tInput :\n\t=> " + RR_Image + "\n\t=> " + msk_Image + "\n\tOutput :\n\t<= " + RR_Results + "\n\t<= " + Morpho_Results, dir + File.separator + log_file_name);
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		File.append("\t" + hour + ":" + minute + ":" + second + " " + dayOfMonth + "/" + month + "/" + year + "\n\n", dir + File.separator + log_file_name);
	}
}

setBatchMode("exit and display");

//End of the macro message
print("\n\n===>End of the " + macro_name + " macro");
print("Check output files in:\n" + dir);
print("- " + log_file_name + "\n- *" + Morpho_suffix + "\n- *" + RRInt_suffix + "\n(*) For each image analyzed");