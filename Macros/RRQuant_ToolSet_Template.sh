#!/bin/bash
# Generates The toolSet macro file from the individaal macros of the RRQuant workflow
# To run, open a terminal where this file and where the individual macro files are located and run the line: $ bash RRQuant_ToolSet_Template.sh > RRQuant_Workflow_ToolSet.ijm

echo 'macro "SplitLargeImage Action Tool - C000 T0508S T5508p Ta508l Td508i Tg508t T0h08I T2h08m Tah08g" {'
cat SplitLargeImage.ijm
echo '};'

echo ' '

echo 'macro "MaskConvert Action Tool - C000 T0508M T7508a Tc508s Tg508k T0h08C T6h08o Tbh08n Tgh08v" {'
cat MaskConvert.ijm
echo '};'

echo ' '

echo 'macro "RRQuant Action Tool - C000 T0510R T7510R T0h08Q T7h06u Tbh06a Tfh06n Tjh06t" {'
cat RRQuant.ijm
echo '};'

echo ' '

echo 'macro "HelpRRQuant Action Tool - C000 T0a10H T7a10e Tda10l Tfa10p" {'
cat HelpRRQuant.ijm
echo '};'




