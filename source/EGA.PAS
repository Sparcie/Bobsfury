{ 
  EGA Graphics unit made for Bob's fury as part of a replacement for
  the BGI. Same interface as the VGA unit so it's easy to use them
  interchangably.
  
  A Danson 2023
 }

unit ega;

interface

{basic start-up and shutdown}
procedure init;
procedure shutdown;
procedure cls;

{basic drawing stuff - lines and boxes}
procedure line(x,y,x1,y1 : word; c : byte);
procedure filledBox(x,y,x1,y1: word; c : byte);
procedure putPixel(x,y : word; c : byte);
procedure circle(x,y,radius: word; colour: byte);

{basic blitting stuff - get and put in gwbasic terms}
{this will tell you how much memory to allocate to a
 pointer for a given screen area}
function imageSize(sx,sy:word):word;
procedure getImage(x,y,x1,y1 : word; bitmap : pointer);
procedure putImage(x,y : word; bitmap : pointer);
procedure putImageXOR(x,y : word; bitmap : pointer);

{Page swapping/flipping support}
procedure setVisualPage(p : byte);
procedure setDrawingPage(p : byte);

implementation

uses fixed,gcommon;

const
   cardSeg			   = $A000;
   {bitmask for selecting a single pixel}
   pixel     : array[0..7] of byte = ($80, $40, $20, $10, $08, $04, $02, $01);
   {bitbask for selecting a range of leading horizontal pixels}
   leadmask  :array[0..7] of byte = ($FF, $7f, $3F, $1F, $0F, $07, $03, $01); 
   {bitmask for selecting a range of trailing horizontal pixels}
   trailmask :array[0..7] of byte = ($80, $C0, $E0, $F0, $F8, $FC, $FE, $FF); 
   {plane mask for selecting a plane}
   planes : array[0..3] of byte = ( $01, $02, $04, $08 );
   
var
   inited   : boolean; {have we started the display?}
   exitSave : pointer;
   lastmode : byte;
   pageofs  : word; {ofset to the current page we are drawing to - you need to be sure a page exists there}
   {this section stores what we've set EGA registers to (only ones I plan on using)}
   datafunc  : byte; {the rotate and alu function selected}
   readplane : byte; {the plane selected for reading data (read mode 0)}
   mode      : byte; {the read and write mode selection register}
   bitmask   : byte; {the bitmask register (selects which pixels to operate on)}
   planemask : byte; {selects which planes are active for writing}

{this function calculates the screen ofset needed to draw a pixel}
function screenOfset(x,y : word):word; assembler;
asm
  {calculates the following formula...
      ofs := (x shr 3) + y * 80;
      ofs := ofs + pageofs; }
  {store and determine the x component in BX}
  mov bx, x 
  shr bx,1 { it is quicker to shr bx,1 3 times than it is to use shr bx,cl }
  shr bx,1  
  shr bx,1
  {now do the y component - store result in ax }
  mov cx, y
  shl cx,1 {same as before - four instructions is faster than one }
  shl cx,1
  shl cx,1
  shl cx,1
  mov ax,cx
  shl cx,1
  shl cx,1
  add ax,cx
  {now add in the x component}
  add ax,bx
  {add page ofset (for the multipaging aspect of EGA}
  add ax, pageofs
end;

{use EGA BIOS to set the page we are displaying}
procedure setVisualPage(p : byte); assembler;
asm
   mov ah, $05
   mov al, p
   int $10
end;

procedure setDrawingPage(p : byte);
begin
   pageofs := 16384 * p;
end;

{check if co-ordinates are on screen in vesa mode}
function checkEBounds(x,y:word):boolean; assembler; {returns true on failure!}
asm
    mov ax, 0
    mov bx, x
    mov cx, y
    cmp bx, 639
    ja @failed
    cmp cx, 199
    ja @failed
    jmp @done
@failed:
    mov al, 1
@done:
end;

{set the data rotate/function register}
procedure setDatafunc(d :  byte); assembler;
asm
    mov ah, d
    mov al, datafunc
    cmp ah, al
    je @skip
    mov datafunc, ah
    mov al, 3
    mov dx, $3CE
    out dx, ax    
@skip:
end;

{set the read map select register (essentially the the plane to read)}
procedure setReadPlane(d : byte); assembler;
asm
    mov ah, d
    mov al, readplane
    cmp ah, al
    je @skip
    mov readplane, ah
    mov al, 4
    mov dx, $3CE
    out dx, ax    
@skip:
end;

{set the read and write mode}
procedure setMode(d : byte); assembler;
asm
    mov ah, d
    mov al, mode
    cmp ah, al
    je @skip
    mov mode, ah
    mov al, 5
    mov dx, $3CE
    out dx, ax    
@skip:
end;

{set the bit mask (for selecting which pixels to affect)}
procedure setBitMask(d : byte); assembler;
asm
    mov ah, d
    mov al, bitmask
    cmp ah, al
    je @skip
    mov bitmask, ah
    mov al, 8
    mov dx, $3CE
    out dx, ax    
@skip:
end;

{set the read map select register (essentially the the plane to read)}
procedure setPlaneMask(d : byte); assembler;
asm
    mov ah, d
    mov al, planemask
    cmp ah, al
    je @skip
    mov planemask, ah
    mov al, 2
    mov dx, $3C4
    out dx, ax    
@skip:
end;

{basic start-up and shutdown}
procedure init;
begin
     if (inited) then exit;
     asm
        mov ax, $0f00
        int $10
        mov lastmode, al
        mov ax, $000E
        int $10
     end;
     inited := true;
     cls;
end;

procedure cls;
begin
   setMode(2);
   setBitMask($FF);
   setDataFunc(0);
   setPlaneMask($F);
   fillmem(cardseg, pageofs, 0, 16000);   
end;

{$f+}

procedure newexitproc;
begin
   if inited then shutdown;
   exitproc := exitsave;
end;
{$f-}

{shutdown procedure - return to text mode}
procedure shutdown;
begin
     asm  {back into text mode}
        mov ah, $00
        mov al, lastmode
        int $10
     end;
     inited := false;
end;


{basic drawing stuff - lines and boxes}

{line drawing routine, using bresenhams line algorithm}
procedure line(x,y,x1,y1: word; c: byte);
var
   count,xs,ys,xm,ym : integer;
   cx,cy	     : word;
   ofs		     : word;
   mask, dummy       : byte;
begin
   if checkEBounds(x,y) then exit;
   if checkEBounds(x1,y1) then exit;
   
   setMode(2);
   setDataFunc(0);
   setPlaneMask($F);
   
   xs := Integer(x1) - x; ys := Integer(y1)-y;

   xm:= sign(xs); ym := sign(ys) * 80 ;
   xs := abs(xs); ys := abs(ys);

   ofs := screenOfset(x,y);

   mask := pixel[x and $7];

   {check for zero length lines}
   if ((xs = 0) and (ys=0)) then
   begin
      setbitMask(mask);
      dummy := mem[cardseg:ofs];
      mem[cardseg:ofs] := c;
      exit;
   end;

   if xm < 0 then
   begin
      {swap the co-ords so we draw left to right}
      swapW(x,x1);
      swapW(y,y1);
      ys := Integer(y1) -y;
      ym := sign(ys) * 80;
      ys := abs(ys);
      xs := Integer(x1) - x;
      xm := sign(xs);
      xs := abs(xs);
      ofs := (x shr 3) + y * 80;
      ofs := ofs + pageofs;
      mask := pixel[x and $7];
   end;
   
   if xs >= ys then
   begin
      { register assignments for drawing lines ...
      ES:DI - location of memory to modify
      AH - current bitmask
      AL - current bit for current pixel.
      BX - error variable for drawing lines
      CX - count of number of pixels
      DX - $3CE for writing the bit mask }
      asm
         mov ax, cardseg
         mov es, ax
         mov di, ofs
         mov ah, mask
         mov al, ah
         xor bx,bx
         sub bx, xs
         sar bx, 1
         mov cx, xs
         mov dx, $3CE

      @xstart:
         { add next pixel }
         shr al, 1
         jnc @xsamebyte
         {need to draw the current byte - set bitmask and draw it}
         mov al, 8
         out dx, ax
         mov al, [es:di] {dummy read}
         mov al, c       {load colour from stack}
         mov [es:di], al  {write colour}
         mov ax, $8080    {set new start pixel}
         inc di          {next byte}
      @xsamebyte:
         {check if we need to move up/down a row}
         add bx, ys
         cmp bx, 0
         jl @xsamerow
         {ok move a row - first draw the byte we have built.}
         push ax
         mov al, 8
         out dx, ax
         mov al, [es:di] {dummy read}
         mov al, c       {get colour}
         mov [es:di], al {write}
         pop ax
         mov ah,al       { restart building bitmask}
         add di, ym      { move pointer }
         sub bx, xs 
      @xsamerow:
         or ah, al {add the current bit to the bitmask we're building}
         loop @xstart
         {draw last byte }
         mov al, 8
         out dx, ax
         mov al, [es:di]
         mov al, c
         mov [es:di], al
      end;
   end
   else
   begin
      { register assignments for vertical line drawing
      ES:DI - pointer to where we are working
        AH - current bit
        BX - error variable for bresenhams
        CX - count of number of pixels
        DX - $3CE for writing bit mask to card }
      asm
         mov ax, cardseg
         mov es, ax
         mov di, ofs
         mov ah, mask
         xor bx,bx
         sub bx, ys
         sar bx, 1
         mov cx, ys
         mov dx, $3CE

         {draw first pixel}
         mov al, 8
         out dx, ax {set bitmask}
         mov al, [es:di] {dummy read}
         mov al, c       {get colour}
         mov [es:di], al {write colour}

      @ystart:
         {check if we need to move horizontally}
         add bx, xs
         cmp bx, 0
         jl @ysamecolumn
         {change column we're in}
         sub bx, ys
         shr ah, 1
         jnc @ychangemask
         inc di
         mov ah, $80
      @ychangemask:
         mov al, 8
         out dx, ax
      @ysamecolumn:
         add di, ym {move pointer to next row for drawing}
         mov al, [es:di] {dummy read}
         mov al, c {get colour}
         mov [es:di], al {write colour}
         loop @ystart
      end;
   end;
   setbitMask(0);
end;

{filled box routine}
procedure filledBox(x,y,x1,y1: word; c : byte);
var
   mask	  : byte;
   dummy  : byte;
   ofs	  : word;
   row	  : word;
   column : word;
   width  : word;
begin
   if checkEBounds(x,y) then exit;
   if checkEBounds(x1,y1) then exit;
   if (x>x1) then
      swapW(x,x1);
   if (y>y1) then
      swapW(y,y1);
   {set registers for the whole operation}
   setMode(2);
   setDataFunc(0);
   setPlaneMask($F);

   {first we're going to draw all the leading pixels in the box.}
   mask := leadmask[ x and $7 ];
   ofs := screenOfset(x,y);
   {check if the width of the box is narrow, we might only need to draw using one byte}
   if ((x shr 3) = (x1 shr 3)) then
   begin
      {both start and end of the rows are in the lead byte,
       for this special case we just adjust the mask and only draw the leading edge }
      mask := mask and trailmask[ x1 and $7];
   end;  
   
   setBitMask(mask); {settting the bit mask register}

   {draw loop for leading edge}
   for row:= y to y1 do
      begin
	 dummy := mem[cardseg:ofs]; {dummy read to load latch}
	 mem[cardseg:ofs] := c;     {write the colour in write mode 2}
	 ofs := ofs + 80;           {next row}
      end;

   {ok if we only need to draw the leading byte we can stop here}
   if ((x shr 3) = (x1 shr 3)) then exit;

   {ok now we need to draw all the intermediate pixels between the leading byte and trailing byte}
   {first we need to figure out how many byte there are to fill.}
   width := (x1 - x - 1) shr 3;
   {only do this section if there are bytes to fill}
   if (width>0) then
   begin
      setBitMask($FF); { we filling all the pixels in the byte }
      ofs := ((x shr 3) + y * 80) + 1 + pageofs; {calculate ofset}
      for row := y to y1 do
      begin
	 for column := 1 to width do
	    begin
	       dummy := mem[cardseg:ofs]; {dummy read to load latch}
	       mem[cardseg:ofs] := c;     {write the colour in write mode 2}
	       inc(ofs);
	    end;
	 ofs := ofs + 80 - width;
      end;
   end;

   {ok now we should only need to draw the portion in the trailing bytes}
   {work out the trailing mask}
   mask := trailmask[x1 and $7];
   setBitMask(mask);
   {work out offset (in bytes)}
   ofs := (x1 shr 3) + (y * 80) + pageofs;

   {draw the trailing edge}
   for row := y to y1 do
      begin
	 dummy := mem[cardseg:ofs]; {dummy read to load latch}
	 mem[cardseg:ofs] := c;     {write the colour in write mode 2}
	 ofs:= ofs + 80;
      end;

   {ok we should be done!}
end;

{put pixel routine, not the fastest way to draw}
procedure putPixel(x,y : word; c : byte);
var ofs	 : word;
   dummy : byte;
begin
   if checkEBounds(x,y) then exit;
   setMode(2);
   setBitMask(pixel[x and $7]);
   setDataFunc(0);
   setPlaneMask($F);
   ofs := screenOfset(x,y);
   dummy := mem[cardseg: ofs]; {dummy read to load latch}
   mem[cardseg:ofs] := c;
end;

{basic blitting stuff - get and put in gwbasic terms}
{this will tell you how much memory to allocate to a
 pointer for a given screen area}
function imageSize(sx,sy:word):word;
begin
     imageSize := ((sx shr 3)  + 1  ) * 4 * sy + 6;
end;

{gets an image and stores it in a chunk of memory, be sure to allocate enough memory}
procedure getImage(x,y,x1,y1 : word; bitmap : pointer);
var
   bseg,bofs   : word; { current location in buffer we are writing to }
   sofs	       : word; { source starting ofset }
   i,c	       : word; { counters for loops }
   sizex,sizey : word; { size of the image }
   rowSize     : word; {bytes per row (for a single plane)}
   pixels      : word; {pixel data we have read}
   shift       : byte; {how much we have to shift the data to align it}
   plane       : byte; {current plane we are reading}
begin
   if checkEBounds(x,y) then exit;
   if checkEBounds(x1,y1) then exit;
   bseg := seg(bitmap^);
   bofs := ofs(bitmap^);
   if x1<x then swapW(x,x1);
   if y1<y then swapW(y,y1);
   sizex := (x1 - x) + 1;
   sizey := (y1 - y) + 1;
   fillmem(bseg, bofs, 0, imageSize(sizex, sizey));
   rowSize := (sizex shr 3) + 1;
   memw[bseg:bofs] := sizex;
   memw[bseg:bofs+2] := sizey;
   bofs := bofs + 4; {set to begining of buffer}
   shift := (x and 7);
   {figure out the starting address from the source}
   

   for plane := 0 to 3 do
   begin
      setReadPlane(plane);
      sofs := screenOfset(x,y);
      for c:= y to y1 do
      begin
	 for i := 1 to rowsize do
	    begin
	       pixels := memw[cardseg: sofs];
	       pixels := swap(pixels) shl shift;
	       mem[bseg:bofs] := hi(pixels);
	       inc(bofs);
	       inc(sofs);	       
	    end;
	 sofs := sofs - rowsize + 80;
      end;
   end;

end;

{copies a monochrome buffer to the screen, use registers to set which plane and bitmasks }
{written in pascal to be upgraded to assembly}
procedure copyToScreen(tofs, bseg, bofs, bwidth, rwidth, rows : word); assembler;
asm
{ ES:DI - source data from buffer
  DS:SI - target on screen
  AX - dummy read register
  CX - loop counter - width
  DX - loop counter - rows}
   push ds
   {load segment and index registers}
   mov ax, bseg
   mov es, ax
   mov ax, bofs
   mov di, ax
   mov ax, cardseg
   mov ds, ax
   mov ax, tofs
   mov si, ax
   mov cx, rwidth
   mov dx, rows
   {validate the counters (0 is invalid)}
   cmp cx, 0
   jz @skip
   cmp dx, 0
   jz @skip

@loop:
   {inner loop - do ega draw for CX bytes}
   mov al, [ds : si] {dummy read to load latch}
   mov al, [es : di] {get buffer data}
   mov [ds : si], al {put buffer data to EGA}
   inc si
   inc di
   loop @loop
   {outer loop portion - repeat for number of rows}
   {adjust ofsets for next row}
   add si, 80
   sub si, rwidth
   add di, bwidth
   sub di, rwidth
   {reset CX counter}
   mov cx, rwidth
   { check outer loop condition}
   dec dx
   jnz @loop

@skip:
   {loop done! restore data segment and return}
   pop ds
end;			

{puts an image to the screen, is a direct copy}
procedure putImage(x,y : word; bitmap : pointer);
var
   bseg,bofs   : word; { buffer pointer}
   tofs	       : word; { target ofset and current ofset}
   sizex,sizey : word; { sizes}
   bwidth      : word; { width of the buffer }
   bheight     : word; { height of the buffer in pixels}
   rwidth      : word; { width of section to copy }
   maskS       : byte; { mask for begining }
   maskE       : word; { mask for trailing byte(s) }
   plane       : byte; { the current plane we are drawing to }
begin
   if checkEBounds(x,y) then exit;
   bseg := seg(bitmap^);
   bofs := ofs(bitmap^);
   sizex := memw[bseg:bofs];
   sizey := memw[bseg:bofs+2];
   bheight := sizey;
   bofs := bofs + 4;
   tofs := screenOfset(x,y);
   bwidth := (sizex shr 3) + 1; {buffer width in bytes}
   if (x+sizex>639) then {check we're not going to draw off screen}
      sizex := 640-x;
   if (y+sizey>199) then 
      sizey := 200-y;
   rwidth := (sizex shr 3); { how many bytes to write excluding the last byte }
   setMode(0);  { drawing write mode 0 }
   setDataFunc( x and $7 ); { set up rotate to line up data with where we are drawing }
   maskS := leadmask[ x and $7]; 
   maskE := swap(trailMask[ (sizex - 1) and $7 ]) shr (x and $7);  

   for plane := 0 to 3 do
   begin
      {set the plane we are working with.}
      setPlaneMask(planes[plane]);
      {draw the bytes for the first mask}
      setBitMask(maskS);
      copyToScreen(tofs, bseg, bofs, bwidth, rwidth, sizey);

      if not(maskS = $FF) then
      begin	 
	 {change the mask and draw those bytes (only if needed)}
	 setBitMask(not(maskS));
	 copyToScreen(tofs + 1 , bseg, bofs, bwidth, rwidth, sizey);
      end;

      {draw trailing data if any}
      if hi(maskE) <> 0 then
      begin
	 setBitMask(hi(maskE));
	 copyToScreen( tofs + rwidth , bseg, bofs + rwidth , bwidth, 1, sizey);
      end;

      if lo(maskE) <> 0 then
      begin
	 setBitMask(lo(maskE));
	 copyToScreen( tofs + rwidth + 1 , bseg, bofs + rwidth , bwidth, 1, sizey);
      end;
      
      bofs := bofs + ( bwidth * bheight);
   end;
   
end;

{puts an image to the screen, XORs it with what's already on screen.}
{ The EGA implementation is basically the same as for copy put just
  selecting a different logical function for the ALU in the EGA }
{ could be easily modified to do AND or NOT as well }
procedure putImageXOR(x,y : word; bitmap : pointer);
var
   bseg,bofs   : word; { buffer pointer}
   tofs	       : word; { target ofset and current ofset}
   sizex,sizey : word; { sizes}
   bwidth      : word; { width of the buffer }
   bheight     : word; { height of the buffer in pixels}
   rwidth      : word; { width of section to copy }
   maskS       : byte; { mask for begining }
   maskE       : word; { mask for trailing byte(s) }
   plane       : byte; { the current plane we are drawing to }
begin
   if checkEBounds(x,y) then exit;
   bseg := seg(bitmap^);
   bofs := ofs(bitmap^);
   sizex := memw[bseg:bofs];
   sizey := memw[bseg:bofs+2];
   bheight := sizey;
   bofs := bofs + 4;
   tofs := screenOfset(x,y);
   bwidth := (sizex shr 3) + 1; {buffer width in bytes}
   if (x+sizex>639) then {check we're not going to draw off screen}
      sizex := 640-x;
   if (y+sizey>199) then 
      sizey := 200-y;
   rwidth := (sizex shr 3); { how many bytes to write excluding the last byte }
   setMode(0);  { drawing write mode 0 }
   setDataFunc( $18 or (x and $7) ); { set up rotate to line up data with where we are drawing }
   maskS := leadmask[ x and $7]; 
   maskE := swap(trailMask[ (sizex - 1) and $7 ]) shr (x and $7);  

   for plane := 0 to 3 do
   begin
      {set the plane we are working with.}
      setPlaneMask(planes[plane]);
      {draw the bytes for the first mask}
      setBitMask(maskS);
      copyToScreen(tofs, bseg, bofs, bwidth, rwidth, sizey);

      if not(maskS = $FF) then
      begin	 
	 {change the mask and draw those bytes (only if needed)}
	 setBitMask(not(maskS));
	 copyToScreen(tofs + 1 , bseg, bofs, bwidth, rwidth, sizey);
      end;

      {draw trailing data if any}
      if hi(maskE) <> 0 then
      begin
	 setBitMask(hi(maskE));
	 copyToScreen( tofs + rwidth , bseg, bofs + rwidth , bwidth, 1, sizey);
      end;

      if lo(maskE) <> 0 then
      begin
	 setBitMask(lo(maskE));
	 copyToScreen( tofs + rwidth + 1 , bseg, bofs + rwidth , bwidth, 1, sizey);
      end;

      bofs := bofs + ( bwidth * bheight);
   end;
end;
   


procedure circle(x,y,radius: word; colour: byte);
{circle algorithm from SWAG that uses integers}
var
   a, af, b, bf,
   target, r2 : word;
   yofs : word; {the y offset into the vga memory}
   clip : boolean;
begin
     if checkEBounds(x,y) then exit;
     clip := false;
     if (x< radius) or (y<radius) then clip :=true;
     if (639-x<radius) or (199-y<radius) then clip := true;
     target := 0;
     a := radius;
     b := 0;
     r2 := radius * radius;

     while (a>=b) do
     begin
          b:= intsqrt(R2 - (a*a)) ;
          swapW(target, b);
          while (b<target) do
          begin
              {af := (120 * a) div 100;  Aspect correction results in
              bf := (120 * b) div 100;   missing stripes}

              {new aspect correction now changes the y value}
              {also uses 4:3 aspect ratio}
              {now also includes calculation for memory ofset}
              af:= ((a * 3) div 6) {* 320} ;
              bf:= ((b * 3) div 6) {* 320} ;
              {yofs := (y * 320) + targofs} ;

	      putpixel(x+a,y+bf,colour);
	      putpixel(x+b,y+af,colour);
	      putpixel(x-a,y+bf,colour);
	      putpixel(x-b,y+af,colour);
	      putpixel(x-a,y-bf,colour);
	      putpixel(x-b,y-af,colour);
	      putpixel(x+a,y-bf,colour);
	      putpixel(x+b,y-af,colour);
              inc(b);
          end;
          dec(a);
     end;
end;


begin
   inited := false;
   exitSave := exitproc;
   exitproc := @newexitproc;
   {set values to something that will cause a port write when needed}
   datafunc := 0;
   pageofs := 0;
   readplane := $FF;
   mode := $FF;
   bitmask := 0;
   planemask :=0;
end.
