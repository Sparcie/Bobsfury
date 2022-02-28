unit pgs; {pack graphics system for lrs and hrs files packed using packer.pas
           by A Danson 2000}
{modified in 2010 to include collision detection between pictures}
{modified in 2013 to use the buffered reader.}
{modified in 2014 to read RLE files}
{modified in 2015 to be responsible for loading BGI drivers and initialising graph}

interface
uses graph,buffer;

procedure loadpack(name: string);
procedure ega;
procedure cga;
procedure lowres;
procedure hires;
procedure textscreen;
procedure draw(x,y:integer;puttype:word;image:integer);
procedure unloadpack;
function collision(x,y,f,x2,y2,f2 :integer ):boolean;
function spriteCount:integer;
procedure spriteSize(var sx,sy : integer);

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

   procedure checkGraphResult(error : string );
   var
      gr : integer; {graph result}
   begin
     gr := graphresult;
      if (gr<>grok) then
      begin
	 writeln(error);
	 writeln(grapherrormsg(gr));
	 halt(1);
      end;
   end;


   function loadBGIDriver(bgidriver : string):integer;
   var
      gr : integer; {graph result}
   begin
      loadBGIDriver := installuserdriver(bgidriver, nil);
      checkGraphResult('Could not load BGI driver');
   end;

   procedure startGraphics(driver, mode	: integer);
   begin
      initgraph(driver,mode,'.');
      checkGraphResult('Could not start graphics');
   end;

procedure cga;
begin
   startGraphics(1,3);
   inited:=true;
end;

procedure ega;
begin
   startGraphics(3,0);
   inited:=true;
end;

procedure lowres ;
begin
   startGraphics(loadBGIDriver('vga256'),0);
   inited:=true;
end;

procedure hires;
begin
   startGraphics(loadBGIDriver('vesa'),1);
   inited:=true;
end;

procedure draw(x,y:integer; puttype:word;image:integer);
begin
     if (loaded and (image <=number) and (image>0) ) then
	 putimage(x,y,pic[image]^,puttype);
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
	 putpixel(i,c,data);
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
	 putpixel(i,c,ord(a));
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
	 picsize[num] := imagesize(0,0,ssx-1,ssy-1);
	 getmem(pic[num],picsize[num]);
	 getimage(0,0,ssx-1,ssy-1,pic[num]^);
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
   if inited then closegraph;
end;

begin
   loaded:=false;
   inited:=false;
end.
