{vga packed graphics to ega packed graphics converter}
{ created for adding ega support to bobsfury.}
{A Danson 2012}
{$G+ 286 instructions}
{$N+ co-processor enabled}
{$E+ co-processor emulation if needed} 

program egaconv;

uses pgs, palette, vga, gpack;

var
   translation	: array[0..15,0..15] of word;
   sx,sy	: integer;
   num, current	: integer;
   s		: string;

function getPixel(x,y : word):byte;
begin
   getPixel := mem[$A000 : x + (y*320)];
end;


procedure clearTranslation;
var
   i,c : integer;
begin
   for i:= 0 to 15 do
      for c:= 0 to 15 do
	 translation[i,c] := 0;
end;

{from swag hopefully this arccos will work!}
function Arccos(x : real):real;
begin
   if x >= 1.0 then
      arccos:=0
   else if x <= -1.0 then
      arccos:= Pi
   else
      arccos := -arctan(x/sqrt(-sqr(x)+1))+(pi/2);      
end;

function colourDifference(r,g,b,x,y,z : integer):integer;
var
   cp	 : real;
   l1,l2 : real;
   ang	 : real;
begin
   cp := (r*x) + (g*y) + (b*z);
   l1 := sqrt((r*r) + (g*g) + (b*b));
   l2 := sqrt((x*x) + (y*y) + (z*z));
   ang := cp / (l1*l2);
   ang := arccos(ang); {angle is in radians}
   {what to do with the angle?!}
   {convert to degrees?}
   ang := ang * (180 / Pi);
   colourDifference := trunc(ang)+ abs(trunc(l1 -l2));
end;

function paldistance(i, c :byte ):integer;
var
   ir,ig,ib : byte;
   cr,cg,cb : byte;
   result   : integer;
   a,b	    : integer;
begin
   palette.getColor(i,ir,ig,ib);
   palette.getColor(c,cr,cg,cb);
   result := colourDifference(ir,ig,ib,cr,cg,cb);
   paldistance := result;
end;

function mixedDistance(i, c, x :byte ):integer;
var
   ir,ig,ib : byte;
   cr,cg,cb : byte;
   xr,xg,xb : byte;
   result   : integer;
   a,b,d    : integer;
begin
   palette.getColor(i,ir,ig,ib);
   palette.getColor(c,cr,cg,cb);
   palette.getColor(x,xr,xg,xb);

   a:= (ir div 2) + (cr div 2);
   b:= (ig div 2) + (cg div 2);
   d:= (ib div 2) + (cb div 2);
   
   result := colourDifference(xr,xg,xb,a,b,d);
   mixedDistance := result;
end;

function translate(c : integer):integer;
var
   x,y	  : integer;
   bc,bd  : integer;
   d	  : integer;
   bm,bmd : integer;
   
begin
   {check for previous translations}
   for x:= 0 to 15 do
      for y:= 0 to 15 do
	 if translation[x,y] = c then
	 begin
	    translate := (x shl 8) + y;
	    exit;
	 end;
   {find the nearest colour in the ega palette}
   bc := 0;
   bd := 1000;
   for x:= 1 to 15 do
      begin
	 d := paldistance(x,c);
	 if d<bd then
	 begin
	    bd:=d;
	    bc:=x;
	 end;
      end;
   {find the best mixer colour!}
   bm := 0;
   bmd := 1000;
   for x:= 1 to 15 do
      if translation[bc,x] = 0 then
      begin
	 d := mixeddistance(x,bc,c);
	 if d<bmd then
	 begin
	    bmd:=d;
	    bm:=x;
	 end;
      end;
   if translation[bc,bm] = 0 then
      translation[bc,bm] := c
   else
   begin
      translation[bm,bc] := c;
      translate := (bm shl 8) + bc;
      exit;
   end;
   translate := (bc shl 8) + bm;
end;

procedure convertSprite(sp:integer);
var
   i,c : integer;
   pix : integer;
begin
   clearTranslation;
   draw(0,0,copyput,sp);
   for c:= 0 to sy-1 do
      for i:= 0 to sx-1 do
      begin
	 pix:=getPixel(i,c);
	 if pix>0 then pix:=translate(pix);
	 spriteData(chr(hi(pix)));
	 spriteData(chr(lo(pix)));
      end;
end;

begin
   {check the params and make sure we have some}
   if (paramCount < 2) then
   begin
      writeln(' Vga to Ega packed graphics converter');
      writeln(' A J Danson 2012');
      writeln('usage:egaconv infile outfile');
      halt(0);
   end;
   initVGA;
   loadpack(paramstr(1));
   clearTranslation;
   num := spriteCount;
   spriteSize(sx,sy);
   newfile(paramstr(2),num,sx*2,sy);
   {start converting graphics!}
   for current := 1 to num do
   begin
      convertSprite(current);
   end;
   {done!}
   unloadpack;
   textscreen;
   str(num,s);
   writeln('Sprites - '+s);
   num := closeFile;
   str(num,s);
   writeln('Compressed - '+s+' sprites');
end.
