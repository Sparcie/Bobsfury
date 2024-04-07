{Graphics library for bobsfury!}
{A Danson 2000}

{ updated to include collision detection (2010)}
{ updated for more graphics modes and removal of vgavesa 2014}
{ updated in 2022 for removing the BGI library }

{$I defines.pas}

unit bobgraph;
interface

{normal uses}
uses pgs,map,bsound
{conditional defines for each graphics mode}
{$ifdef CGA}
,cga
{$ENDIF}
{$ifdef VGA}
,vga
{$endif}
{$ifdef EGA}
,ega
{$endif}
{$ifdef VESA}
,vesa
{$endif}
;

procedure startgraphics;
procedure clearviewport;
function iSize(x,y : integer):word;
procedure showscreen;
procedure easydraw(c,i:integer);
procedure finish;
procedure spritedraw(x,y,ob:integer; putt:word);
{procedure textxy(x,y,size,c:integer;s:string);}
procedure line(x,y,x2,y2,c:integer);
procedure bar(x,y,x2,y2,c:integer);
procedure explode(x,y:integer);
procedure mapp(x,y:integer);
procedure mdis(x,y:integer);
procedure bulex(x,y:integer);
procedure disolve(x,y:integer);
procedure save(x,y,width,height : integer);
procedure restore;
procedure drawAnimations;
procedure clearanims;
function animCount:integer;
function collision(x,y,f,x2,y2,f2 :integer ):boolean;

{functions for switching from the UI page to the game screen }
{using page flipping we have separate pages for the UI and game screen
page 0 is for the game.
page 1 is for the UI.
}
procedure UIPage;
procedure GamePage;

const
   mCGA	    = 0; { 320x200 4 colour}
   mEGA	    = 1; { 640x200 16 colour }
   mVGA	    = 2; { 320x200 256 colour }
   mVESA    = 3; { 640x400 256 colour }
   copyput  = 0;
   xorput   = 1;
   transput = 2; {not implemented yet}

var
   graphicsMode	: byte;
   paging	: boolean;
   
implementation

uses palette, vgapal, bsystem;

type anim = record
   start  : boolean;
   x,y	  : integer;
   f,endf : integer;	       
end;	  


var	   
   saved   : pointer; {saved bitmap}
   isSaved : boolean; {is the bitmap filled}
   isPaged : boolean; {is there a copy of the game screen in the back buffer}
   sx,sy   : integer; {location of saved bitmap on screen}
   memSize : integer; {size of saved image}
   anims   : array[0..61] of anim;
   size	   : integer;

procedure adjustCoords(var x,y : integer);
begin
   case graphicsmode of
     mEGA  : x := x shl 1;
     mVESA : begin
		x := x shl 1;
		y := y shl 1;
	     end;
   end;
end;

procedure cgaUIColour(var c : integer);
begin
   if c=9 then c:=3;
   if c=5 then c:=2;
   if c=13 then c:=1;
   if c=8 then c:=2;
end;

procedure UIPage;
begin
   case graphicsmode of
     {$ifdef EGA}
     mEGA : begin
	       ega.setVisualPage(1);
	       ega.setDrawingPage(1);
	    end;
     {$endif}
     {$ifdef CGA}
     mCGA : begin
	       if isPaged then exit;
	       isPaged:= true;
	       cga.copyToBuffer;
	    end;
     {$endif}
     {$ifdef VGA}
     mVGA : begin
	       if isPaged then exit;
	       isPaged := true;
	       vga.copyToBuffer;
	    end;
     {$endif}
   end;
end; { UIPage }

procedure GamePage;
begin
   case graphicsmode of
     {$ifdef EGA}
     mEGA : begin
	       ega.setDrawingPage(0);
	       ega.setVisualPage(0);
	    end;
     {$endif}
     {$ifdef CGA}
     mCGA : begin
	       if not(isPaged) then exit;
	       isPaged:=false;
	       cga.copyToScreen;
	    end;
     {$endif}
     {$ifdef VGA}
     mVGA : begin
	       if not(isPaged) then exit;
	       isPaged:=false;
	       vga.copyToScreen;
	    end;
     {$endif}
   end;
end; { GamePage }

function collision(x,y,f,x2,y2,f2 :integer ):boolean;
begin
   adjustcoords(x,y);
   adjustcoords(x2,y2);
   collision := pgs.collision(x,y,f,x2,y2,f2);
end;

function animCount:integer;
begin
   animcount:=size;
end;

procedure startgraphics;
var
   zeropal : paltype;
   i	   : integer;
   b	   : boolean;
   inited  : boolean;
   gcard   : byte;
begin
   gcard := detectGraphics;
   paging := false;
   inited := false;
   if graphicsMode>3 then graphicsMode:=2;
   {$ifdef CGA}
   if graphicsMode=mCGA then
   begin
      if gcard<2 then
      begin
	 writeln('CGA not supported on this machine');
	 halt(0);
      end;
      initcga;
      CGAPalette(2,0);
      if memavail > 57384 then
	 b := cga.setdrawmode(1);
      loadpack('gdata.cga');
      if memavail > 65536 then
	 paging := cga.setdrawmode(2)
      else
	 b := cga.setdrawmode(0);
      inited := true;
   end;
   {$endif}
   {$ifdef EGA}
   if graphicsMode=mEGA then
   begin
      if gcard<3 then
      begin
	 writeln('EGA not supported on this machine');
	 halt(0);
      end;
      initega;
      paging := false;
      if ((EGAmem>0) or (gcard>3)) then paging := true;
      loadpack('gdata.ega');
      inited := true;
   end;
   {$endif}
   {$ifdef VESA}
   if  graphicsMode=mVESA then
   begin
      if gcard<5 then
      begin
	 writeln('VESA BIOS extension not found');
	 halt(0);
      end;
      for i:= 0 to 255 do
      begin
	 zeropal[i,0] :=0;
	 zeropal[i,1] :=0;
	 zeropal[i,2] :=0;
      end;
      for i:= 0 to 15 do {set some colours so we can draw the progress bar}
      begin
	 zeropal[255-i,0] := stdpal[i,0];
	 zeropal[255-i,1] := stdpal[i,1];
	 zeropal[255-i,2] := stdpal[i,2];
      end;
      initvesa;
      setPalette(zeropal);
      loadpack('gdata.hrp');
      setPalette(stdpal);
      inited := true;
   end;
   {$endif}
   {$ifdef VGA}
   if graphicsmode=mVGA then
   begin
      if gcard<4 then
      begin
	 writeln('VGA not supported on this machine');
	 halt(0);
      end;
      initvga;
      if memavail > 92000 then
	 b := vga.setdrawmode(1);
      loadpack('gdata.lrp');
      if memavail > 65536 then
	 paging:= vga.setdrawmode(2)
      else
	 b := vga.setdrawmode(0);
      inited:= true;
   end;
   {$endif}
   if not(inited) then
   begin
      writeln('Graphics mode not supported');
      halt(0);
   end;
end;

function iSize(x,y : integer):word;
begin
   iSize := 0;
   case graphicsmode of
     {$ifdef CGA }
     mCGA : iSize := cga.imagesize(x,y);
     {$endif}
     {$ifdef EGA }
     mEGA : iSize := ega.imagesize(x,y);
     {$endif}
     {$ifdef VGA}
     mVGA : iSize := vga.imagesize(x,y);
     {$endif}
     {$ifdef VESA}
     mVESA: iSize := vesa.imagesize(x,y);
     {$endif}
   end;
end;

procedure clearviewport;
begin
   case graphicsmode of
     {$ifdef CGA }
     mCGA : cga.cls;
     {$endif}
     {$ifdef EGA }
     mEGA : ega.cls;
     {$endif}
     {$ifdef VGA }
     mVGA : vga.cls;
     {$endif}
     {$ifdef VESA }
     mVESA: vesa.cls;
     {$endif}
   end;
end;

procedure showscreen;
var i,c	: integer;
   x,y	: integer;
begin
   
   bar(0,0,310,160,0);

   {bar(0,160,312,161,6);}
   bar(0,160,312,161,15);
   bar(311,161,312,0,15);
   bar(0,161,313,162,7);
   bar(312,162,313,0,7);
   bar(0,162,313,162,8);
   bar(313,162,313,0,8);
   i:=0;
   c:=0;
   while i<16 do
   begin
      x:=c;
      y:=i;
      adjustcoords(x,y);
      draw(x*10,y*10,0,objectat(c,i));
      c:=c+1;
      if c=31 then
      begin
	 i:=i+1;
	 c:=0;
      end;
   end;
end;

procedure easydraw(c,i:integer);
begin
   adjustcoords(c,i);
   draw(c*10,i*10,0,objectat(c,i));
   if objectat(c,i) = 0 then
   begin
      bar((c*10),(i),((c+1)*10)-1,((i+1)*10)-1, 0);
   end;
end;

procedure finish;
begin
   if (isSaved) then freemem(saved,memSize);
   unloadpack;
   textscreen;
end;

procedure spritedraw(x,y,ob:integer; putt:word);
begin
   adjustcoords(x,y);
   draw(x,y,putt,ob);
end;

procedure line(x,y,x2,y2,c:integer);
begin
   case graphicsmode of
     {$ifdef CGA}
     mCGA : begin
	       cgaUIColour(c);
	       cga.line(x,y,x2,y2,c);
	    end;
     {$endif}
     {$ifdef VGA}
     mVGA : vga.line(x,y,x2,y2,c);
     {$endif}
     {$ifdef EGA}
     mEGA  : begin
		x := x shl 1;
		x2 := x2 shl 1;
		ega.line(x,y,x2,y2,c);
	     end;
     {$endif}
     {$ifdef VESA}
     mVESA : begin
		x := x shl 1;
		y := y shl 1;
		x2 := x2 shl 1;
		y2 := y2 shl 1;
		vesa.line(x,y,x2,y2,c);
	     end;
     {$endif}
   end;
end;

procedure bar(x,y,x2,y2,c:integer);
begin
   case graphicsmode of
     {$ifdef CGA}
     mCGA : begin
	       cgaUIColour(c);
	       cga.filledBox(x,y,x2,y2,c);
	    end;
     {$endif}
     {$ifdef VGA}
     mVGA : vga.filledBox(x,y,x2,y2,c);
     {$endif}
     {$ifdef EGA}
     mEGA  : begin
		x := x shl 1;
		x2 := x2 shl 1;
		ega.filledBox(x,y,x2,y2,c);
	     end;
     {$endif}
     {$ifdef VESA}
     mVESA : begin
		x := x shl 1;
		y := y shl 1;
		x2 := x2 shl 1;
		y2 := y2 shl 1;
		vesa.filledBox(x,y,x2,y2,c);
	     end;
     {$endif}
   end;
end;

procedure save(x,y,width,height	: integer);
begin
   if (isSaved) then freemem(saved, memSize);
   case graphicsmode of
     {$ifdef CGA}
     mCGA : begin
	       sx:=x;
	       sy:=y;
	       isSaved := true;
	       memSize := cga.imageSize(width+1,height+1);
	       if memsize>maxavail then
	       begin
		  textscreen;
		  writeln('out of memory');
		  halt(0);
	       end;
	       getmem(saved,memSize);
	       cga.getImage(x,y,(x+width),(y+height), saved);
	    end;
     {$endif}
     {$ifdef VGA}
     mVGA : begin
	       sx:=x;
	       sy:=y;
	       isSaved := true;
	       memSize := vga.imageSize(width+1,height+1);
	       if memsize>maxavail then
	       begin
		  textscreen;
		  writeln('out of memory');
		  halt(0);
	       end;
	       getmem(saved,memSize);
	       vga.getImage(sx,sy,(sx+width),(sy+height), saved);
	    end;
     {$endif}
     {$ifdef EGA}
     mEGA : begin
	       sx:=x shl 1;
	       sy:=y;
	       width := width shl 1;
	       isSaved := true;
	       memSize := ega.imageSize(width+1,height+1);
	       if memsize>maxavail then
	       begin
		  textscreen;
		  writeln('out of memory');
		  halt(0);
	       end;
	       getmem(saved,memSize);
	       ega.getImage(sx,sy,(sx+width),(sy+height), saved);
	    end;
     {$endif}
     {$ifdef VESA}
     mVESA : begin
		sx:=x shl 1;
		sy:=y shl 1;
		width := width shl 1;
		height := height shl 1;
		isSaved := true;
		memSize := vesa.imageSize(width+1,height+1);
		if memsize>maxavail then
		begin
		   textscreen;
		   writeln('out of memory');
		   halt(0);
		end;
		getmem(saved,memSize);
		vesa.getImage(sx,sy,(sx+width),(sy+height), saved);
	    end;
   {$endif}
   end;
end; { save }

procedure restore;
begin
   if not(issaved) then exit;
   case graphicsmode of
     {$ifdef CGA}
     mCGA : cga.putimage(sx,sy,saved);
     {$endif}
     {$ifdef EGA}
     mEGA : ega.putimage(sx,sy,saved);
     {$endif}
     {$ifdef VGA}
     mVGA : vga.putimage(sx,sy,saved);
     {$endif}
     {$ifdef VESA}
     mVESA: vesa.putimage(sx,sy,saved);
     {$endif}
   end;
   freemem(saved,memSize);
   issaved:=false;
end; { restore }

procedure explode(x,y:integer);
begin
   bsound.xplode;
   if (size=61) then exit;
   anims[size].x:=x;
   anims[size].y:=y;
   anims[size].f:=102;
   anims[size].endf:=107;
   anims[size].start:=true;
   size:=size+1;
end;

procedure disolve(x,y:integer);
begin
   bsound.xplode;
   if (size=61) then exit;
   anims[size].x:=x;
   anims[size].y:=y;
   anims[size].f:=126;
   anims[size].endf:=135;
   anims[size].start:=true;
   size:=size+1;
end;

procedure mapp(x,y:integer);
begin
   bsound.showmonst;
   if (size=61) then exit;
   anims[size].x:=x;
   anims[size].y:=y;
   anims[size].f:=98;
   anims[size].endf:=102;
   anims[size].start:=true;
   size:=size+1;

end;

procedure mdis(x,y:integer);
begin
   bsound.hidemonst;
   if (size=61) then exit;
   anims[size].x:=x;
   anims[size].y:=y;
   anims[size].f:=98;
   anims[size].endf:=102;
   anims[size].start:=true;
   size:=size+1;  

end;

procedure bulex(x,y:integer);
begin
   if x<0 then x:=0;
   if y<0 then y:=0;	
   if (size=61) then exit;
   anims[size].x:=x;
   anims[size].y:=y;
   anims[size].f:=111;
   anims[size].endf:=116;
   anims[size].start:=true;
   size:=size+1;  

end;


procedure drawAnimations;
var i : integer;
begin
   i:=0;
   while (i< size) do
   begin
      if not(anims[i].start) then
      begin
	 spritedraw(anims[i].x,anims[i].y,anims[i].f,xorput);
	 anims[i].f:=anims[i].f+1;
      end;
      anims[i].start:=false; 
      if (anims[i].f<anims[i].endf) then
	 spritedraw(anims[i].x,anims[i].y,anims[i].f,xorput)
      else
      begin
	 if (size>0) then anims[i]:=anims[size-1];
	 size:=size-1;
	 i:=i-1;
      end;
      i:=i+1;
   end;
end;

procedure clearanims;
begin
   size:=0;
end;

begin
   graphicsMode:=2;
   paging := false;
   size:=0;
   issaved:=false;
   isPaged:=false;
end.
