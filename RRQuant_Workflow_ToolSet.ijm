macro "SplitLargeImage Action Tool - C000 T0508S T5508p Ta508l Td508i Tg508t T0h08I T2h08m Tah08g" {
///======================MACRO=========================///
macro_name = "SplitLargeImage";
///====================================================///
///File author(s): Stephane Verger======================///

///====================Description=====================///
/* This macro takes as input an image already openned in 
 * ImageJ. Running the macro helps cropping, re-naming with
 * standardize naming and saving several times in a row, 
 * sub areas of a large image.
 * For further details see macro_source.
*/
macro_source = "https://github.com/VergerLab/RRQuant";
///=============Predified default values===============///
sample = "col-0"
stain = "NonStained"
repNb = "1"
///====================================================///
///====================================================///
///====================================================///

// Define output folder
outdir = getDirectory("Choose a directory to save output");

do{ //Do...while loop over the whole set of sub area cropping from large image
	// Select rectangle tool and wait for user selection
	setTool("rectangle");
	waitForUser("Select Area to crop", "With the pre-selected rectangle tool, select the area of the image to be cropped and saved.\nThen click ok.");
	
	//Dialog: User defines variables for image name
	Dialog.create("New image name");
	Dialog.addMessage("Define the name of the image (Genotpes/conditions, Stained/non stained, replicate number)");
	Dialog.addMessage("DO NOT LEAVE SPACES IN THE NAMES, USE _ INSTEAD");
	Dialog.addMessage("DO NOT USE SPECIAL CHARACTERS");
	Dialog.addMessage("DO NOT USE -- ");
	Dialog.addString("Genotpes/conditions names", sample);
	Dialog.addChoice("stained of non stained", newArray("Stained", "NonStained"), stain);
	Dialog.addNumber("replicate nb", repNb);
	Dialog.show();
	sample = Dialog.getString();
	stain = Dialog.getChoice();
	repNb = Dialog.getNumber();
	ImgName = sample + "--" + stain + "--rep_" + repNb + "--img";
	
	//Duplicate, rename and save the image
	run("Duplicate...", " ");
	saveAs("Tiff", outdir + ImgName + ".tif");
	selectImage(ImgName + ".tif");
	close();
	
	//Dialog: More cropping?
	Dialog.create("More?");
	Dialog.addMessage(ImgName + ".tif was succesfully saved.");
	Dialog.addMessage("Do you want to crop more areas of the large image?");
	Dialog.addChoice("More", newArray("Yes", "No, I'm done"));
	Dialog.show();
	More = Dialog.getChoice();
	
} while (More == "Yes");};
 
macro "MaskConvert Action Tool - C000 T0508M T7508a Tc508s Tg508k T0h08C T6h08o Tbh08n Tgh08v" {
///======================MACRO=========================///
macro_name = "MaskConvert";
///====================================================///
///File author(s): Stephane Verger======================///

///====================Description=====================///
/* This macro takes as input original .tif RGB images of 
 * stained samples and .png masks segmented with root painter.
 * It converts the mask to 8-bit binary images, filters 
 * minor segmentation errors allows further manual 
 * corrections and output an new .png mask to be used 
 * within the RRQuant workflow.
 * For further details see macro_source.
*/
macro_source = "https://github.com/VergerLab/RRQuant";

///=========Input/output file names parameters=========///
// Input paramaters: input files suffixes
RPMask_suffix = "--img.png"; //Root painter mask
Img_suffix = "--img.tif"; //Original image

// Output paramaters: output file suffixes
MSK_suffix = "--msk.png"; //Add new suffix to differentiate converted/corrected mask

///====================================================///
///====================================================///
///====================================================///

print("\\Clear");

//Select directory
dir = getDirectory("Choose a directory");
dir_name = File.getName(dir);
dir_list = getFileList(dir);

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
	if(endsWith (dir_list[i], RPMask_suffix)){
		print("file_path", dir + dir_list[i]);
			
		//count samples analyzed
		s++;
		
		//Extract generic name and path of the image serie
		File_name = substring(dir_list[i], 0, indexOf(dir_list[i], RPMask_suffix));

		//Write to log txt file
		File.append("- Sample number: " + s + "\n" + File_name, dir + File.separator + log_file_name);
		print("Sample: " + File_name);
		print("--> Opening input images");
		
		//Open Rootpainter mask
		RPMask_Image = File_name + RPMask_suffix;
		open(dir + RPMask_Image);
		
		//Rename as msk image
		MSK_Image = File_name + MSK_suffix;
		MSK_File_name = substring(MSK_Image, 0, indexOf(MSK_Image, ".png"));
		rename(MSK_Image);
				
		//Convert Root painter rgb mask to 8-bit mask
		run("8-bit");
		setAutoThreshold("Default no-reset");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		
		//Filtering Mask by size
		run("Analyze Particles...", "size=5000-Infinity exclude include add");
		roiNb = roiManager("count");
		rois = newArray(roiNb);
		for (j = 0; j < roiNb; j += 1) {
			rois[j] = j;
		}
		roiManager("Select", rois);
		roiManager("Combine");
		run("Clear Outside");
		roiManager("Show None");
		selectWindow("ROI Manager");
		run("Close");

		//Open original image
		Img_Image = File_name + Img_suffix;
	    open(dir + Img_Image);
		
		//Make an overlay of ROI on original image 
		selectWindow(Img_Image);
		run("Enhance Contrast", "saturated=0.35");
		wait(100);
		run("8-bit Color", "number=256");
		wait(100);
		run("Images to Stack", "use");
		
		//Manual corrections
		waitForUser("Manual correction (if needed)", "1) Select the color picker tool, and click somewhere in the black background.\n2) Select the paintbrush tool (Note: double click on the paintbrush tool to change its size).\n3) Draw on the image to remove region which had not been properly segmented.\n4) Select again the color picker tool, and click somewhere in the white foreground.\n5) Select again the Paintbrush tool and draw on the image to add region which had not been properly segmented.\n \nOnce the image is fully corrected, click ok");			

		//Split stack and re-convert to mask and apply pixel size
		run("Stack to Images");
		selectImage(MSK_File_name);
		run("8-bit");
		setAutoThreshold("Default no-reset");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		run("Invert");

		//Save converted/corrected mask
		saveAs("PNG", dir + MSK_Image);
		
		//Close images
		close("*");
		
		//Write to log, input files used, output file generated, time and date
		File.append("\tInput :\n\t=> " + RPMask_Image + "\n\t=> " + Img_Image + "\n\tOutput :\n\t<= " + MSK_Image, dir + File.separator + log_file_name);
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		File.append("\t" + hour + ":" + minute + ":" + second + " " + dayOfMonth + "/" + month + "/" + year + "\n\n", dir + File.separator + log_file_name);
	}
}

//End of the macro message
print("\n\n===>End of the " + macro_name + " macro");
print("Check output files in:\n" + dir);
print("- " + log_file_name + "\n- *" + MSK_suffix + "\n(*) For each image analyzed");
};
 
macro "RRQuant Action Tool - C000 T0510R T7510R T0h08Q T7h06u Tbh06a Tfh06n Tjh06t" {
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
		print (unit);
		if (unit=="inches"){
			waitForUser("Wrong unit", "The image unit and pixel size may be incorrect.\nCheck image properties.");
		}
		
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
print("- " + log_file_name + "\n- *" + Morpho_suffix + "\n- *" + RRInt_suffix + "\n(*) For each image analyzed");};
 
macro "HelpRRQuant Action Tool - C000 T0a10H T7a10e Tda10l Tfa10p" {
///======================MACRO=========================///
macro_name = "HelpRRQuant";
///====================================================///
///File author(s): Stéphane Verger=====================///

///====================Description=====================///
/*This macro simply provides a link to the code repo with 
 * help and user guide.
*/
macro_source = "https://github.com/VergerLab/RRQuant/";

print("https://github.com/VergerLab/RRQuant");
waitForUser("Help", "For help and details on how to use this workflow see\n https://github.com/VergerLab/RRQuant\n(Copy and access the link address displayed in the log window)");};
