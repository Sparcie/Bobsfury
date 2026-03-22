echo off
egaconv gdata.lrp gdata.ega
echo EGA Conv
pause
cgaconv gdata.lrp gdata.cga
echo CGA Conv
pause
hgcconv gdata.cga hgcout.pgs
echo hercules conversion
copy hgcdata.pgs gdata.hgc
pause
copy gdata.* ..\
copy gdata.* ..\..\
copy gdata.lrp ..\..\bfleu\
copy gdata.hrp ..\..\bfleu\