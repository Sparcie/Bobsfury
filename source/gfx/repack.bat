packer hrslist.txt gdata.hrp
packer lrslist.txt gdata.lrp
pause
rem testpack gdata.lrp
rem testpack gdata.hrp
copy gdata.* ..\
copy gdata.* ..\..\bfleu\
cd ..
egaconv gdata.lrp gdata.ega
cgaconv gdata.lrp gdata.cga
copy gdata.* ..\
cd gfx