# RRQuant
Image processing workflow for the analysis of Ruthenium red stained Arabidopsis dark grown hypocotyls.

## Installation
- Requirements:
  - Fiji
  - MorpholibJ Plugin
- Procedure:
  - Copy the RRQuant_Workflow_toolset.ijm file to your Fiji "macros/Toolset folder".
  - Access the tools from the right end side of Fiji window ">>" (More tools).

## Usage
Starting from large tile stereo microscope images of ruthenium red stained samples.
1) Split large images per genotype/condition, stained/non-stained, replicates (__SplitLargeImage.ijm__).
2) Run segmentation with root painter (https://github.com/Abe404/root_painter/tree/master), using our model trained for RR stained hypocotyls segmentation (__coming...__).
3) Convert/correct root painter masks (__MaskConvert.ijm__).
4) Run staining intensity and morphometrics quantification (__RRQuant.ijm__).
5) Analyze data with R (__coming...__).

All ImageJ Macro (__SplitLargeImage.ijm__, __MaskConvert.ijm__ and __RRQuant.ijm__) are packaged in an imageJ toolset laid out from left to right, but the individual macro soucres are also available in the macros folder.
