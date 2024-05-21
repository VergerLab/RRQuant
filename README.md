# RRQuant
Image processing workflow for the analysis of Ruthenium red stained Arabidopsis dark grown hypocotyls.

## Installation
- Requirements:
  - Fiji
  - MorpholibJ Plugin
- Procedure:
Copy the RRQuant_Workflow_toolset.ijm file to your Fiji "macros/Toolset folder".
Access the tools from the right end side of Fiji window ">>" (More tools).

1) Acquire large images
2) Split per genotype/condition, stained/non stained, replicates (SplitLargeImage.ijm).
3) Run segmentation with root painter (https://github.com/Abe404/root_painter/tree/master), using model trained for RR stained hypocotyls (coming...).
4) Convert/correct root painter masks (MaskConvert.ijm).
5) Run staining intensity and morphometrics quantification (RRQuant.ijm).
6) Analyze data with R (coming...).
