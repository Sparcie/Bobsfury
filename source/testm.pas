program test;
uses FMMusic,SynthInt,music,bmusic;

var i,c,z:integer;
    n:note;
begin
setChannel(default3,1,both);

{ Anthem }
   writeln('anthem');
fmmusic.PlayMusic('T100O3L8E-.L16CO2L4A-O3L4CE-L2A-O4L8C.O3L16B-L4A-CDL2E-L8E-E-O4L4C.'+
  'O3L8B-L4A-L2GL8FGL4A-A-E-CO2L4A-O4L8CCL4CD-E-L2E-L8D-CO3L4B-O4L4CD-L2D-L8D-'+
  'D-L4C.O3L8B-L4A-L2GL8FL16G.L4A-CDL2E-L8E-E-L4A-A-L8A-GL4FFFB-O4L8D-CO3L8B-'+
  'A-L4A-L4G.P8L8E-E-O3L4A-.L8B-O4L8CD-L2E-O3L8A-B-O4L4C.L8D-O3L4B-L2A-..P1',1);
while (buffersize(1)>0 ) do;

{ Anvil }
   writeln('anvil');
fmmusic.PlayMusic('T200O3E2E4.E8E4.D8C4.O2A8G4.B8O3D4.F8E2C2E2E4.E8E4.D8C4.O2A8G4.B8'+
  'O3D4.F8E4C4E2C4P4D4P4O2B4O3C4O2A4B4E4P4P8G+8A8B8O3C4C4P8O2B8O3C8D8E4E4P8D8'+
  'E8F8G2.F8G16F16E4P4P2',1);
while (buffersize(1)>0 ) do;

{ Bouree }
   writeln('Bouree');
fmmusic.PlayMusic('MBMLL8T150O4DEF4EDC+4DEO3A4BO4C+DP10CO3B-A4GFE4FGAP16GF16E16D8P10'+
  'O4DEF4EDA4FAO3A4BO4C+DP10CO3B-A4GFP32F16G16F16E16F16.P32F2',1);
while (buffersize(1)>0 ) do;

writeln('digger2 (my tune by random key mashings!');
fmmusic.PlayMusic('abbcdefggfcdeafgedgfcd' ,1);
while (buffersize(1)>0 ) do;

writeln('test higer speed');
fmmusic.playmusic('l64o0abcdefgo1abcdefgo2abcdefgo3abcdefgo4abcdefgo5abcdefgo6abcdefgo7abcdefg',1);
while (buffersize(1)>0 ) do;
writeln('Music is done.');

writeln('testing bmusic');
{writeln('loading from disk all files');
loadlist('..\music\');
changesong;}
wait;
newfile(1);
channel(1);
setinstrument(default1);
n.length := 16;
for z:=1 to 9 do 
 for c:=0 to 7 do
 for i:=1 to 12 do
 begin
    insert;
    n.oct:=c;
    n.note:=i;
    setnote(n);
 end;
play;
write('playing ');
writeln(memavail);
wait;
writeln('done');
writeln('saving');
save('test.bfm');
writeln('loading');
load('test.bfm');
write('playing again ');
writeln(memavail);
play;
wait;
end.
