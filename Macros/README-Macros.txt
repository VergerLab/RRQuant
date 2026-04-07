The RRQuant macro can be used with the newest version of MorphoLibJ (v1.6.5). 
If an older version of MorphoLibJ is used (v1.6.4), the line 27 of the RRQuant macro file should be replaced by the line below: 

Morpho_Measurments = "pixel_count area perimeter circularity euler_number bounding_box centroid equivalent_ellipse ellipse_elong. convexity max._feret oriented_box oriented_box_elong. geodesic tortuosity max._inscribed_disc average_thickness geodesic_elong.";

This line is also directly in the RRQuant.imj file as a commented line (lines 29-30).
