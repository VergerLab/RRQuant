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
	
} while (More == "Yes");