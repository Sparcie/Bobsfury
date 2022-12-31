{vga packed graphics to cga packed graphics converter}
{ created for adding cga support to bobsfury.}
{A Danson late 2013}
{$G+ 286 instructions}
{$N+ co-processor enabled}
{$E+ co-processor emulation if needed} 

program cgaconv;

uses pgs, palette, vga, gpack;

var
   sx,sy	: integer;
   num, current	: integer;
   colcount	: array[0..255] of word; {counts the number of each colour}
   translation	: array[0..255] of byte; {the CGA colour that a colour is to be translated to}
   cgaused	: array[0..3] of boolean;
   cgapal	: array[1..3,1..3] of byte;
   cn		: array[0..3] of byte; {colour neighbour counts}
   s		: string;

function getPixel(x,y : word):byte;
begin
   getPixel := mem[$A000 : x + (y*320)];
end;

procedure clearTranslation;
var
   i,c : integer;
begin
   for i:= 0 to 255 do
   begin
      colcount[i]:=0;
      translation[i] := $FF;
   end;
   translation[0] := 0;
   cgaused[1]:=false;
   cgaused[2]:=false;
   cgaused[3]:=false;   
end;

{from swag hopefully this arccos will work!}
function Arccos(x : double):double;
begin
   if x >= 1.0 then
      arccos:=0
   else if x <= -1.0 then
      arccos:= Pi
   else
      arccos := -arctan(x/sqrt(-sqr(x)+1))+(pi/2);      
end;

function colourDifference(r,g,b,x,y,z : integer):double;
var
   cp	 : double;
   l1,l2 : double;
   ang	 : double;
begin
   cp := (r*x) + (g*y) + (b*z);
   l1 := sqrt((r*r) + (g*g) + (b*b));
   l2 := sqrt((x*x) + (y*y) + (z*z));
   ang := cp / (l1*l2);
   ang := arccos(ang); {angle is in radians}
   {what to do with the angle?!}
   {convert to degrees?}
   ang := ang * (180 / Pi);
   colourDifference := abs(ang)+ abs(l1-l2);
end;

function colourAngle(r,g,b,x,y,z : integer):double;
var
   cp	 : double;
   l1,l2 : double;
   ang	 : double;
begin
   cp := (r*x) + (g*y) + (b*z);
   l1 := sqrt((r*r) + (g*g) + (b*b));
   l2 := sqrt((x*x) + (y*y) + (z*z));
   ang := cp / (l1*l2);
   ang := arccos(ang); {angle is in radians}
   {what to do with the angle?!}
   {convert to degrees?}
   ang := ang * (180 / Pi);
   colourAngle := abs(ang);
end;

function paldistance(i, c :byte ):double;
var
   ir,ig,ib : byte;
   cr,cg,cb : byte;
   result   : double;
   a,b	    : integer;
begin
   palette.getColor(i,ir,ig,ib);
   palette.getColor(c,cr,cg,cb);
   result := colourDifference(ir,ig,ib,cr,cg,cb);
   paldistance := result;
end;

function nearestCGAColour(c : byte): byte;
var
   d	 : double;
   bestd : double;
   bestc : integer;
   i	 : integer;
   r,g,b : byte;
begin
   bestd:=50000000000000000000.0;
   bestc:=0;
   palette.getColor(c,r,g,b);
   for i:= 1 to 3 do
   begin
      d:= colourDifference(cgapal[i,1], cgapal[i,2],cgapal[i,3],r,g,b);
      if ((d<bestd) and not(cgaused[i])) then
      begin
	 bestd := d;
	 bestc := i;
      end;
   end;
   nearestCGAColour := bestc;
end;

function translate(i : byte): byte;
begin
   translate := translation[i];
end; { translate }

procedure neighbourCGAColours(colour : byte);
var i,c	 : integer;
   pix,t : byte;
begin
   for i:= 0 to 3 do
      cn[i] := 0;
   for c:= 0 to sy-1 do
      for i:= 0 to sx-1 do
      begin
	 if pix = colour then
	 begin
	    if ((c>0) and not( translate(getPixel(i,c-1)) = $FF)) then
	       inc(cn[translate(getPixel(i,c-1))]);
		
	    if ((c<sy) and not( translate(getPixel(i,c+1)) = $FF)) then
	       inc(cn[translate(getPixel(i,c+1))]);
	    
	    if ((i>0) and not( translate(getPixel(i-1,c)) = $FF)) then
	       inc(cn[translate(getPixel(i-1,c))]);
		
	    if ((i<sx) and not( translate(getPixel(i+1,c)) = $FF)) then
	       inc(cn[translate(getPixel(i+1,c))]);		
	 end;
      end;
   {everything done!}
end;

{next colour to translate, basically the one with the highest count}
function nextColour:byte;
var
   i  : integer;
   bc : word;
   nc : byte;
begin
   nc:= 0;
   bc:= 0;
   for i:= 1 to 255 do
      if colcount[i]>bc then
      begin
	 bc := colcount[i];
	 nc := i;
      end;
   colcount[nc] := 0; {set so this colour isn't repeated}
   nextColour := nc;
end;

procedure convertColours; 
var
   c	  : byte;
   i	  : integer;
   bnc,bn : byte;
   s	  : string;
   a	  : char;
begin
   filledBox(0,80,319,199,0); {clear display}
   
   {convert the first three colours - if there are three!}
   i:=0;
   c := nextColour;
   while ((c>0) and (i<3)) do
   begin
      translation[c] := nearestCGAColour(c);
      cgaused[translation[c]] := true;
      c:= nextColour;
      inc(i);
   end;
   {clear the used flags for the next bit}
   for i:=0 to 3 do
      cgaused[i]:=false;
   
   {next we need to convert any that remain - we will use the colour which turns up as a neighbour the least frequent}
   while (c>0) do
   begin
      neighbourCGAColours(c);
      bnc := nearestCGAColour(c);
      bn := $FF;
      for i:= 0 to 3 do
      begin
	 if (cn[i]<=bn) then
	 begin
	    bn:=cn[i];
	    bnc:=i;
	 end;
      end;
      translation[c] := bnc;
      c:=nextColour;
   end;
   
   {while not(keypressed) do ;
      
   while keypressed do a:=readkey;}
end; { convertColours }

procedure changeColour(oc,nc : byte);
var
   i,c : integer;
   pix : byte;
begin
   for c:= 0 to sy-1 do
      for i:= 0 to sx-1 do
      begin
	 pix := getPixel(i,c);
	 if pix=oc then
	    putPixel(i,c,nc);
      end;
end;

{checks all the used colours to see if any should be merged into the same colour before conversion}
procedure mergeColours;
var
   i,c : integer;
   d   : double;
   s,t : string;
   a   : char;
begin
   {check if we even need to do it!}
   c:= 0;
   for i:= 1 to 255 do
      if colcount[i]>0 then inc(c);
   if c<4 then exit;
   for i:= 1 to 255 do
      for c:= 1 to 255 do
	 if ((colcount[c]>0) and (colcount[i]>0) and (i<>c)) then
	 begin
	    d:= paldistance(c,i);
	    {str(d,s);
	    bar(40,40,300,70);
	    setColor(3);
	    outtextxy(40,40,'d:'+s);
	    str(i,s);
	    setColor(i);
	    outtextxy(40,50,'i:'+s);
	    str(c,s);
	    setColor(c);
	    outtextxy(40,60,'c:'+s);
	    while not(keypressed) do ;

            while keypressed do a:=readkey;}
	    if d<10 then
	    begin
	       if (colcount[c]>colcount[i]) then
	       begin
		  changeColour(i,c);
		  colcount[c] := colcount[c] + colcount[i];
		  colcount[i] := 0;
	       end
	       else
	       begin
		  changeColour(c,i);
		  colcount[i] := colcount[c] + colcount[i];
		  colcount[c] := 0;
	       end;
	    end;
	 end;
end;



procedure convertSprite(sp:integer);
var
   i,c : integer;
   pix : byte;
begin
   clearTranslation;
   draw(0,0,copyput,sp);
   for c:= 0 to sy-1 do
      for i:= 0 to sx-1 do
      begin
	 pix := getPixel(i,c);
	 if pix>0 then
	    inc(colcount[pix]);
      end;
   mergeColours;
   convertColours;
   for c:= 0 to sy-1 do
      for i:= 0 to sx-1 do
      begin
	 pix:=getPixel(i,c);
	 if pix>0 then pix:=translate(pix);
	 spriteData(chr(pix));
      end;
end;

procedure initCGAPAL;
var
   r,g,b : byte;
begin
   {palette for mode 0 is 10, 12, 14}
   {palette for mode 1 is 11, 13, 15}
   {palette for mode 2 is 2,4,6}
   {palette for mode 3 is 3,5,7}
   {using my own definition to try and improve the quality!}
   palette.getColor(3,r,g,b);
   cgapal[1,1] := r;
   cgapal[1,2] := g;
   cgapal[1,3] := b;
   palette.getColor(5,r,g,b);
   cgapal[2,1] := r;
   cgapal[2,2] := g;
   cgapal[2,3] := b;
   palette.getColor(7,r,g,b);
   cgapal[3,1] := r;
   cgapal[3,2] := g;
   cgapal[3,3] := b;
end;

begin
   {check the params and make sure we have some}
   if (paramCount < 2) then
   begin
      writeln(' Vga to Cga packed graphics converter');
      writeln(' A J Danson 2013');
      writeln('usage:cgaconv infile outfile');
      halt(0);
   end;
   initVGA;
   initCGAPAL;
   loadpack(paramstr(1));
   clearTranslation;
   num := spriteCount;
   spriteSize(sx,sy);
   newFile(paramstr(2),num,sx,sy);
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
