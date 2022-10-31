unit pgs; {pack graphics system for lrs and hrs files packed using packer.pas
           by A Danson 2000}
{modified in 2010 to include collision detection between pictures}
{modified in 2013 to use the buffered reader.}
{modified in 2014 to read RLE files}
{modified in 2015 to be responsible for loading BGI drivers and initialising graph}
{modified in 2022 to move away from the BGI to my own graphics libraries}

interface
{$IFNDEF CGA}
uses buffer,vga, cga, vesa;
{$ELSE}
uses buffer,cga;
{$ENDIF}

procedure loadpack(name: string);
procedure initcga;
{$IFNDEF CGA}
procedure initega;
procedure initvga;
procedure initvesa;
{$ENDIF}
procedure textscreen;
procedure draw(x,y:integer;puttype:word;image:integer);
procedure unloadpack;
function collision(x,y,f,x2,y2,f2 :integer ):boolean;
function spriteCount:integer;
procedure spriteSize(var sx,sy : integer);

const
   mCGA	    = 0; { 320x200 4 colour}
   mEGA	    = 1; { 640x200 16 colour }
   mVGA	    = 2; { 320x200 256 colour }
   mVESA    = 3; { 640x400 256 colour }
   copyput  = 0;
   xorput   = 1;
   transput = 2; {not implemented yet}

implementation

type
   bounds   = record
		 maxx,minx : integer;
		 maxy,miny : integer;
	      end;	   
   boundptr = ^bounds;

var pic		 : array[1..200] of pointer;
   picsize	 : array[1..200] of word;
   boundbox	 : array[1..200] of boundptr;
   loaded,inited : boolean;
   graphicsmode	 : byte;
   number	 : integer;
   ssx,ssy	 : integer; {size of the sprites in pixels}
   

   procedure spriteSize(var sx,sy : integer);
   begin
      if not(loaded) then exit;
      sx:= ssx;
      sy:= ssy;
   end;

   function spriteCount:integer;
   begin
      spriteCount :=0;
      if not(loaded) then exit;
      spriteCount:= number;
   end;

   function collision(x,y,f,x2,y2,f2 :integer ):boolean;
   var
      rx,ry :integer ;
   begin
      if not(loaded) then exit;
      collision:=true;
      x:= x-x2;
      y:= y-y2;
      with boundbox[f]^ do
      begin
	 rx:=x + maxx;
	 ry:=y + maxy;
      end;
      with boundbox[f2]^ do
      begin
	 if ((rx<minx) or (ry<miny)) then
	 begin
	    collision:=false;
	    exit;
	 end;
      end;
      with boundbox[f]^ do
      begin
	 rx:=x + minx;
	 ry:=y + miny;
      end;
      with boundbox[f2]^ do
      begin
	 if ((rx>maxx) or (ry>maxy)) then
	 begin
	    collision:=false;
	    exit;
	 end;
      end;
   end;

procedure initcga;
begin
   cga.init;
   inited:=true;
   graphicsmode := mCGA;
end;

{$IFNDEF CGA}
procedure initega;
begin
   writeln('EGA not implemented yet');
   halt(0);
   inited:=true;
end;

procedure initvga ;
begin
   vga.init;
   inited:=true;
   graphicsmode := mVGA;
end;

procedure initvesa;
begin
   vesa.init;
   graphicsmode := mVESA;
   inited:=true;
end;
{$ENDIF}

procedure draw(x,y:integer; puttype:word;image:integer);
begin
   if not(loaded and (image <=number) and (image>0) ) then exit;
   {$IFNDEF CGA}
   case graphicsmode of
     mCGA : begin
	      case puttype of
		copyput	: cga.putImage(x,y,pic[image]);
		xorput	: cga.putImageXor(x,y,pic[image]);
	      end;
	   end;
     mVGA : begin
	      case puttype of
		copyput	: vga.putImage(x,y,pic[image]);
		xorput	: vga.putImageXor(x,y,pic[image]);
	      end;
	   end;
     mVESA : begin
	       case puttype of
		 copyput : vesa.putImage(x,y,pic[image]);
		 xorput	 : vesa.putImageXor(x,y,pic[image]);
	      end;
	   end;
   end;
   {$ELSE}
   case puttype of
     copyput	: cga.putImage(x,y,pic[image]);
     xorput	: cga.putImageXor(x,y,pic[image]);
   end;
   {$ENDIF}
end;

procedure loadImageRLE(var r : reader; var box:bounds);
var
   i,c	 : integer;
   data	 : byte;
   count : byte;
begin
   data := ord(r.readchar);
   count := ord(r.readchar);   
   for c:= 0 to ssy-1 do
      for i:= 0 to ssx-1 do
      begin
	 if count=0 then
	 begin
	    data := ord(r.readchar);
	    count := ord(r.readchar);
	 end;
	 {$IFNDEF CGA}
	 case graphicsmode of
	   mCGA	 : cga.putpixel(i,c,data);
	   mVGA	 : vga.putpixel(i,c,data);
	   mVESA : vesa.putpixel(i,c,data);
	 end;
	 {$ELSE}
	 cga.putpixel(i,c,data);
	 {$ENDIF}
	 if data>0 then
	 begin
	    if box.maxx<i then box.maxx:=i+1;
	    if box.minx>i then box.minx:=i-1;
	    if box.maxy<c then box.maxy:=c+1;
	    if box.miny>c then box.miny:=c-1;
	 end;
	 dec(count);
      end;
end;

procedure loadImageRaw(var r : reader; var box: bounds);
var
   i,c : integer;
   a   : char;
begin
   {check for compression}
   a:= r.readChar;
   if (a=chr($FF)) then
   begin
      loadImageRLE(r,box);
      exit;
   end;
   {read the data raw}
   for c:= 0 to ssy-1 do
      for i:= 0 to ssx-1 do
      begin
	 if ((i>0) or (c>0)) then
	    a:= r.readChar;
	 {$IFNDEF CGA}
	 case graphicsmode of
	   mCGA : cga.putpixel(i,c,ord(a));
	   mVGA : vga.putpixel(i,c,ord(a));
	   mVESA : vesa.putpixel(i,c,ord(a));
	 end;
	 {$ELSE}
	 cga.putpixel(i,c,ord(a));
	 {$ENDIF}
	 if ord(a)>0 then
	 begin
	    if box.maxx<i then box.maxx:=i+1;
	    if box.minx>i then box.minx:=i-1;
	    if box.maxy<c then box.maxy:=c+1;
	    if box.miny>c then box.miny:=c-1;
	 end;
      end;   
end;
			 
procedure loadpack(name:string);
       var imf			  : reader;
	  a			  : char;
	  b,c,d,e,xsize,ysize,num : integer;
	  box			  : bounds;
begin
   if inited then
   begin
      imf.open(name);
      a:= imf.readChar;
      number:=ord(a);
      a:= imf.readChar;
      ssx:=ord(a);
      a:= imf.readChar;
      ssy:=ord(a);
      num:=1;
      while num<=number do
      begin
	 box.maxx:=0; box.minx:=xsize;
	 box.maxy:=0; box.miny:=ysize;
	 loadImageRaw(imf,box);
	 new(boundbox[num]);
	 boundbox[num]^:=box;
	 {$IFNDEF CGA}
	 case graphicsmode of
	   mCGA : begin
		    picsize[num] := cga.imagesize(ssx,ssy);
		    getmem(pic[num],picsize[num]);
		    cga.getimage(0,0,ssx-1,ssy-1,pic[num]);
		 end;
	   mVGA : begin
		    picsize[num] := vga.imagesize(ssx,ssy);
		    getmem(pic[num],picsize[num]);
		    vga.getimage(0,0,ssx-1,ssy-1,pic[num]);
		 end;
	   mVESA : begin
		    picsize[num] := vesa.imagesize(ssx,ssy);
		    getmem(pic[num],picsize[num]);
		    vesa.getimage(0,0,ssx-1,ssy-1,pic[num]);
		 end;
	 end;
	 {$ELSE}
	 picsize[num] := cga.imagesize(ssx,ssy);
	 getmem(pic[num],picsize[num]);
	 cga.getimage(0,0,ssx-1,ssy-1,pic[num]);
	 {$ENDIF}
	 num:=num+1;
      end;
      imf.close;
      loaded:=true;
   end;
end;

procedure unloadpack;
var num:integer;
begin
   num:=1;
   while num<=number do
   begin
      dispose(boundbox[num]);
      freemem(pic[num],picsize[num]);
      num:=num+1;
   end;
   loaded:=false;
end;

procedure textscreen;
begin
   if not(inited) then exit;
   {$IFNDEF CGA}
   case graphicsmode of
     mCGA  : cga.shutdown;
     mVGA  : vga.shutdown;
     mVESA : vesa.shutdown;
   end;
   {$ELSE}
   cga.shutdown;
   {$ENDIF}
end;

begin
   loaded:=false;
   inited:=false;
end.
