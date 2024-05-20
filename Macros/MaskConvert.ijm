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
