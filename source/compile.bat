tpc /B /GD bobtest.pas
pause
tpc /B bfleu.pas /DnoAdlib
pause
tpc /M convert.pas
tpc /M blankmap.pas
tpc /M gedit.pas
tpc /M medit.pas
tpc /M mconvert.pas
tpc /M egaconv.pas
tpc /M cgaconv.pas
tpc /M sndgen.pas
tpc /M mapcomp.pas
sndgen
erase bob.exe
copy bob.snd ..\bob.snd
copy bobtest.exe bob.exe
copy bob.exe ..\bob.exe
copy gedit.exe .\gfx\gedit.exe
copy bfleu.exe ..\bfleu\bfleu.exe
copy mconvert.exe ..\music\mconvert.exe
