///======================MACRO=========================///
macro_name = "Unitfix";
///====================================================///
///File author(s): Stephane Verger======================///

///====================Description=====================///
/* To fix the unit and pixel size for tix images saved 
 *  from LASX (in to mm)
*/
macro_source = "...";

///=========Input/output file names parameters=========///
// Input paramaters: input files suffixes
Img_suffix = "--img.tif"; //Original image
pxsize = 0

///====================================================///
///====================================================///
///====================================================///

print("\\Clear");

//Select directory
dir = getDirectory("Choose a directory");
dir_name = File.getName(dir);
dir_list = getFileList(dir);

s = 0;
//Loop on all the folder in the directory
for (i=0; i<dir_list.length; i++){
	
	//Select image series to process
	if(endsWith (dir_list[i], Img_suffix)){
		print("file_path", dir + dir_list[i]);
		
		//Open image
	    open(dir + dir_list[i]);
		
		//Get pixel size
		pxsize = getNumber("Enter correct pixel size in micron for " + dir_list[i], pxsize);
		
		//Change pixel size
		Stack.setXUnit("micron");
		Stack.setYUnit("micron");
		run("Properties...", "channels=1 slices=1 frames=1 pixel_width=&pxsize pixel_height=&pxsize voxel_depth=25.4001000");

		//Save corrected image
		saveAs("Tiff", dir + dir_list[i]);
		
		//Close images
		close("*");
	}
}

//End of the macro message
print("\n\n===>End of the " + macro_name + " macro");
