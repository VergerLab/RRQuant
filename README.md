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
1) Split large images per genotype/condition, stained/non-stained, replicates (SplitLargeImage.ijm).
2) Run segmentation with root painter (https://github.com/Abe404/root_painter/tree/master), using our model trained for RR stained hypocotyls segmentation (coming...).
3) Convert/correct root painter masks (MaskConvert.ijm).
4) Run staining intensity and morphometrics quantification (RRQuant.ijm).
5) Analyze data with R (coming...).
