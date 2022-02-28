{ packer/compression unit for creating packed graphics files
  this is to replace the old packer program that does not support compression
  it is written in a unit so the the EGA converter and CGA converter can use
  it for compression.}

{A Danson 2014}

unit gpack;

interface

procedure newFile(pf : string; sc,sx,sy:byte);
procedure spriteData(data : char);
function closeFile:integer; {returns the number of compressed sprites}

implementation

uses buffer;

var
   sprite      : array[0..4096] of char; {buffer for the current sprite}
   dataCount   : integer; {amount of data gathered for current sprite}
   sizeX,sizeY : integer; {the size of all the sprites}
   RLEcount    : integer; {the number of RLE sprites}
   w	       : writer; {the buffer writer for writing the file}

function closeFile:integer;
begin
   w.flush;
   w.close;
   closeFile:=RLEcount;
end;

procedure newFile(pf:string; sc,sx,sy:byte);
begin
   w.open(pf);
   sizeX := sx;
   sizeY := sy;
   w.writeChar(chr(sc));
   w.writeChar(chr(sx));
   w.writeChar(chr(sy));
   dataCount := 0;
   RLEcount := 0;
end;

function RLESize:integer;
var
   data	 : char;
   count : byte;
   size	 : integer;
   i	 : integer;
begin
   data:= chr($FF);
   count := 0;
   size:=1; {include the identifying byte $FF}
   for i:=0 to dataCount-1 do
   begin
      if ((data = sprite[i]) and not(count=$FF)) then
      begin
	 inc(count);
      end
      else
      begin
	 if (count>0) then size := size + 2;
	 data := sprite[i];
	 count:= 1;
      end;
   end;
   if count>0 then size:=size + 2;
   RLESize := size;
end;

procedure writeRaw;
var
   i : integer;
begin
   for i:=0 to dataCount-1 do
      w.writeChar(sprite[i]);
end;

procedure writeRLE;
var
   data	 : char;
   count : byte;
   i	 : integer;
begin
   data:= chr($FF);
   count := 0;
   w.writeChar(chr($FF));
   for i:=0 to dataCount-1 do
   begin
      if ((data = sprite[i]) and not(count=$FF)) then
      begin
	 inc(count);
      end
      else
      begin
	 if (count>0) then
	 begin
	    w.writeChar(data);
	    w.writeChar(chr(count));
	 end;
	 data := sprite[i];
	 count:= 1;
      end;
   end;
   if (count>0) then
   begin
      w.writeChar(data);
      w.writeChar(chr(count));
   end;
   inc(RLEcount);
end;

procedure writeSprite;
begin
   {determine if we should use compression or not}
   if RLESize < (sizeX*sizeY) then
      writeRLE
   else
      writeRaw;
   dataCount:=0;
end;

procedure spriteData(data : char);
begin
   sprite[dataCount] := data;
   inc(dataCount);
   if (dataCount = (sizeX*sizeY)) then writeSprite;
end;

end.
