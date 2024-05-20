# RRQuant
Image processing workflow for the analysis of Ruthenium red stained Arabidopsis dark grown hypocotyls.

1) Acquire large images
2) Split per genotype/condition, stained/non stained, replicates (SplitLargeImage.ijm).
3) Run segmentation with root painter (https://github.com/Abe404/root_painter/tree/master), using model trained for RR stained hypocotyls (coming...).
4) Convert/correct root painter masks (MaskConvert.ijm).
5) Run staining intensity and morphometrics quantification (RRQuant.ijm).
6) Analyze data with R (coming...).
