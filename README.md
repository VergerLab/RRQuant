# RRQuant
Image processing workflow for the analysis of ruthenium red stained Arabidopsis dark grown hypocotyls.

## Repository content
- Macros: ImageJ macros.
    - RRQuant_Workflow_ToolSet.ijm contains all necessary tools for RRQuant steps in ImageJ.
    - Other .ijm files contain part of the Tool set that can be use individually.
    - RRQuant_ToolSet_Template.sh generated the toolSet macro file from the individal macros of the RRQuant workflow
- R_scripts:
    - Install_R_packages.R is used to install any missing library in R
    - RRQuant_data-table.R is used to combine the quantification data and organize them to be used in the RRQuant app
    - RRQuant_app.R is the shiny app used to visualize and easily plot the data.
- data: contains test data (csv files) to train on using the R scripts and the RRQuant app. Data have been used in Figure 5.
- models: contains the different versions of the training models used.
- retraining: contains python scripts and a userguide to retrain the model for RootPainter segmentation
- RRQuant_protocol-userguide.pdf explains in details the workflow, from seedling growth to imaging, analysis and data visualization.

## Installation
- Requirements:
  - Fiji (https://imagej.net/software/fiji/downloads)
  - MorpholibJ Plugin (https://imagej.net/plugins/morpholibj)
- Fiji macros:
  - Copy the RRQuant_Workflow_toolset.ijm file to your Fiji "macros/Toolset folder".
  - Access the tools from the right end side of Fiji window ">>" (More tools).
- R Script:
  - See the userguide (https://github.com/VergerLab/RRQuant/blob/main/UserGuide_RRQuant_Rscript.pdf)

## Usage
Starting from large tile stereo microscope images of ruthenium red stained samples.
1) Split large images per genotype/condition, stained/non-stained, replicates (__SplitLargeImage.ijm__).
2) Run segmentation with root painter (https://github.com/Abe404/root_painter/tree/master), using our model trained for RR stained hypocotyls segmentation (__RRQuant_DarkHypo_RPWeight_V1.pkl__).
3) Convert/correct root painter masks (__MaskConvert.ijm__).
4) Run staining intensity and morphometrics quantification (__RRQuant.ijm__).
5) Analyze data with R (__RRQuant_data-table.R__ and __RRQuant_app.R__).

All ImageJ Macro (__SplitLargeImage.ijm__, __MaskConvert.ijm__ and __RRQuant.ijm__) are packaged in an imageJ toolset laid out from left to right, but the individual macro sources are also available in the macros folder. Fore more detailed information see RRQuant_protocol-userguide.pdf.
