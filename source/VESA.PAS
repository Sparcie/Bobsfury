{ 
VESA unit for bobsfury, compatible with VGA.PAS for ease of coding between
the modes. Made as a replacement for the BGI. Works at a fixed resolution
of 640x400, but could be modified for other resolutions.

Because of the nature of higher resolution VESA modes, the back buffer code
is not implemented/available.

This unit works with overflow checking off, there will be errors if it's turned on.

  A Danson 2022
 }

unit vesa;

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
procedure getImage(x,y,x1,y1 :word; bitmap : pointer);
procedure putImage(x,y : word; bitmap : pointer);
procedure putImageXOR(x,y : word; bitmap : pointer);

implementation

uses fixed,gcommon;

type modeinfo = record
		   modeattr	    : word;
		   winAattr	    : byte;
		   winBattr	    : byte;
		   winGran	    : word;
		   winSize	    : word;
		   winAseg	    : word;
		   winBseg	    : word;
		   winfunc	    : pointer;
		   bytesPerScanLine : word;
		   Xres		    : word;
		   Yres		    : word;
		   charwidth	    : byte;
		   charheight	    : byte;
		   planes	    : byte;
		   depth	    : byte;
		   bankCount	    : byte;
		   memoryModel	    : byte;
		   pages	    : byte;
		   reserved	    : byte;
		   padding	    : array[0 .. 224] of byte;
		end;

		const
     cardSeg = $A000;
     cardofs = $0000;		     

var
   inited    : boolean; {have we started the display?}
   exitSave  : pointer;
   mode	     : modeinfo;
   gransize  : word; {VESA granule size measured in 64 byte chunks (64k is $1000)}
   winsize   : word;    {size of the window in bytes for 64k this will be zero}
   grancount : word;    {the number of granules}
   cgran     : word; {The current granule the window is set to}
   lastmode  : byte;

{code to work out which granule a screen co-ordinate is in.}
function granule(x,y : word; var ofs: word): word;
begin
   ofs := y * $28 + (x shr 4);
   granule := ofs div gransize;
   ofs := (ofs shl 4) + (x and $F);
end;


procedure setWindow(w : word); assembler;
asm
   mov ax, $4f05
   xor bx, bx
   mov dx, w
   mov cgran, dx
   int $10
end;

{check if co-ordinates are on screen in vesa mode}
function checkVBounds(x,y:word):boolean; assembler; {returns true on failure!}
asm
    mov ax, 0
    mov bx, x
    mov cx, y
    cmp bx, 639
    ja @failed
    cmp cx, 399
    ja @failed
    jmp @done
@failed:
    mov al, 1
@done:
end;


{basic start-up and shutdown}
procedure init;
var fail  : byte;
begin
     if (inited) then exit;
     fail := 0;
     asm
        {get old mode}
        mov ax, $0f00
        int $10
        mov lastmode, al
        {intialise the VESA graphics}
        {set mode}
        mov ax, $4F02
        mov bx, $100
        int $10
        cmp ax, $0047
        jne @modeset
        mov fail, $FF
        jmp @skip
   @modeset: {successfully set the mode}
        {load the cgran value from the VESA bios (so we know where we are currently}
        mov ax, $4f05
        mov bx, $0100
        int $10
        mov cgran, dx
        {get the size of the granules so we can move the window when needed}
        mov ax, seg(mode)
        mov es, ax
        mov di, offset(mode)
        mov ax, $4F01
        mov cx, $0100
        int $10
        cmp ax, $0047
        jne @skip
        mov fail, $FF   
   @skip: {place to skip to if there is an error}
     end;
     gransize := mode.winGran * $40;
     grancount := $3E80 div gransize;
     winsize:=mode.winSize * 1024;
     if not(fail=0) then
     begin
	shutdown;
	writeln('VESA Graphics not supported on this card');
	halt(0);
     end;
     inited := true;
     cls;
end;

procedure cls;
var
   c  : word;
   gs : word;
begin
   gs := gransize;
   if gs = 0 then gs := $FFFF; {if it's 64K in size this will be zero}
   for c:= 0 to grancount do
   begin
      setWindow(c);
      fillmem(cardseg,0,0,gs);
   end;
end;

{$f+}
procedure newexitproc;
begin
   exitproc := exitsave;
   if inited then shutdown;
end;

{$f-}

{shutdown procedure - return to text mode}
procedure shutdown;
begin
     asm  {the small amount of assembler I will use}
        mov ah, $00
        mov al, lastmode
        int $10
     end;
     writeln('VESA granularity (64byte chunks)',gransize);
     writeln('VESA window size (bytes)',winsize);
     writeln('VESA granule count ', grancount);
     inited := false;
end;

{basic drawing stuff - lines and boxes}


{line drawing routine, using bresenhams line algorithm}
procedure line(x,y,x1,y1: word; c: byte);
var
   count,xs,ys,xm,ym : integer;
   cx,cy	     : word;
   gran, ofs	     : word;
begin
    if checkVBounds(x,y) then exit;
    if checkVBounds(x1,y1) then exit;
    gran := granule(x,y,ofs);
    if not(cgran=gran) then setWindow(gran);
    cx := x; cy := y;
    xs := x1 - x; ys := y1 - y;

    xm:= sign(xs); ym := sign(ys);
    xs := abs(xs); ys := abs(ys);

    mem[cardseg:ofs] := c;
    if (x=x1) and (y=y1) then exit;

    if xs > ys then
    begin
        count := -(xs shr 1);
        while (cx <> x1) do
        begin
            count := count + ys;
            cx:= cx + xm;
            if count>0 then
            begin
                 cy:=cy+ym;
                 count := count - xs;
            end;
            {mem[cardseg:ofs] := c;}
            putpixel(cx,cy,c);
        end;
    end
    else
    begin
         count := -(ys shr 1);
         while (cy <> y1) do
         begin
             count := count + xs;
             cy := cy + ym;
             if count>0 then
             begin
                  cx:=cx + xm;
                  count := count - ys;
             end;
             {mem[cardseg:ofs] := c;}
             putpixel(cx,cy,c);
         end;
    end;
end; 

{filled box routine}
procedure filledBox(x,y,x1,y1: word; c : byte);
var
   row,width : word;
   gran,ofs  : word;
begin
   if checkVBounds(x,y) then exit;
   if checkVBounds(x1,y1) then exit;
   if (x>x1) then
   begin
      swapW(x,x1);
   end;
   if (y>y1) then
   begin
      swapW(y,y1);
   end;
   gran := granule(x,y,ofs);
   if not(gran=cgran) then setWindow(gran);
   width := (x1 - x) + 1;
   row := (y1 - y) + 1;
   asm {conversion to assembly}
      {load card segment and offset into registers}
      mov ax, cardseg
      mov es, ax
      mov ax, ofs
      mov di, ax
      { load the ax register with the colour}
      mov al, c
      mov ah, al
      { load bx with the width }
      mov bx, width
      { put row count in cx, dx will be a temp register for it}
      mov cx, row
   
   @row: {start of a row }
        {detect if the granule boundary is in this row}
        mov dx, di
        add dx, bx
        sub dx, winsize
        cmp dx, bx
        ja @normalrow
      {draw a row with the window border in it}
      push cx {save the row counter}
      mov cx, bx
      mov dx, winsize
   @pixel:
      stosb
      cmp di, dx
      je @changebank
      loop @pixel
      {shouldn't reach this part but it's here in case}
      pop cx {pop cx row data into dx}
      jmp @nobankswitch

   @changebank:
        push ax
        push bx
        mov ax, $4F05
        xor bx, bx
        mov dx, gran
        inc dx
        mov cgran, dx
        int $10
        pop bx
        pop ax
        {set to begining of buffer and copy remaining bytes}
        mov di,0
        rep stosb
        pop cx {pop the cx row data into dx }
        jmp @nobankswitch   

      {draw a row without worrying about the window border}
   @normalrow:
      mov dx, cx {save the current row count into the dx resgiter}
      mov cx, bx  {load the counter with the width}

      shr cx, 1

      rep stosw
      jnc @even
      stosb
   @even:
      mov cx, dx {set cx back to the number of rows}
      {detect if we need to switch banks}
        mov dx, di
        add dx, 640
        sub dx, winsize
        cmp dx, 640
        ja @nobankswitch
        push ax
        push bx
        mov ax, $4F05
        xor bx, bx
        mov dx, gran
        inc dx
        mov cgran, dx
        int $10
        pop bx
        pop ax
        sub di, winsize
    @nobankswitch:
      {move to next row}
      add di, 640
      sub di, bx
      loop @row   
   end;

   {for row := y to y1 do
   begin
      fillmem(cardseg,ofs,c,width);
      ofs := ofs + 640;
      if ((ofs - winsize) <640) then
      begin {we've crossed the granule boundary
	 ofs := ofs - winsize;
	 inc(gran);
	 setWindow(gran);
         if (640- ofs) < width then
  	    fillmem(cardseg,0,c, (640 - ofs));
      end;
   end;}
end;

{put pixel routine, not the fastest way to draw}
procedure putPixel(x,y : word; c : byte);
var
   gran,ofs : word;
begin
    if checkVBounds(x,y) then exit;
    gran := granule(x,y,ofs);
    if not(gran=cgran) then setWindow(gran);
    mem[cardSeg: ofs] := c;
end;

{basic blitting stuff - get and put in gwbasic terms}
{this will tell you how much memory to allocate to a
 pointer for a given screen area}
function imageSize(sx,sy:word):word;
begin
     imageSize := sx * sy + 4;
end;

{gets an image and stores it in a chunk of memory, be sure to allocate enough memory}
procedure getImage(x,y,x1,y1 : word; bitmap : pointer);
var
   bseg,bofs   : word;
   row	       : word;
   gran,sofs   : word;
   sizex,sizey : word;
begin
   if checkVBounds(x,y) then exit;
   if checkVBounds(x1,y1) then exit;
   bseg := seg(bitmap^);
   bofs := ofs(bitmap^);
   if x>x1 then swapw(x,x1);
   if y>y1 then swapw(y,y1);
   gran := granule(x,y,sofs);
   sizex := (x1-x) + 1;
   sizey := (y1-y) + 1;
   memw[bseg:bofs] := sizex;
   memw[bseg:bofs+2] := sizey;
   bofs := bofs + 4;
   for row := y to y1 do
   begin
      copymem(cardseg,sofs,bseg,bofs,sizex);
      bofs := bofs + sizex;
      sofs := sofs + 640;
      if (sofs - winsize<640) then
      begin
	 sofs := sofs - winsize;
	 inc(gran);
	 setWindow(gran);
	 copymem(cardseg,0,bseg, bofs - (640 - sofs), (640 - sofs));
      end;
   end;
end;

{puts an image to the screen, is a direct copy}
procedure putImage(x,y : word; bitmap : pointer);
var
   bseg,bofs   : word;
   gran,sofs   : word;
   sizex,sizey : word;
   width       : word; {copy of the width for updating the source ofset}
   wsize       : word; {copy of winsize so it can be accessed}
begin
     if checkVBounds(x,y) then exit;
     wsize:=winsize;
     bseg := seg(bitmap^);
     bofs := ofs(bitmap^);
     gran := granule(x,y,sofs);
     if not(gran=cgran) then setWindow(gran);
     sizex := memw[bseg:bofs];
     width := sizex;
     sizey := memw[bseg:bofs+2];
     if (x+sizex>639) then
        sizex := 640-x;
     if (y+sizey>399) then
        sizey := 400-y;
     {replaced pascal loop with assembly!}
     asm
        push ds
        {set direction}
        cld
        {set up the counters for the loop}
   
        mov cx, sizey
   
        {set up the segment pointers}
        mov ax, cardseg
        mov es, ax
        mov ax, bseg
        mov ds, ax
        {set up the offset}
        {source}
        mov ax, bofs
        add ax, 4
        mov si, ax
        mov bx, ax {store the ofset in the bx register}
        {screen/buffer ofset}
        mov ax, sofs
        mov di, ax
        mov ax, sizex

        {start of the loop}
        @startrow:
        {do the transfer}
        push cx
        mov cx,ax

        {detect if the granule boundary is in this row}
        mov dx, di
        add dx, ax
        sub dx, wsize
        cmp dx, ax
        ja @normalcopy
        {draw a row with the bank boundary in the middle}
        mov dx, winsize
        @pixel:
        movsb
        cmp di, dx
        je @changeBank
        loop @pixel
        pop cx
        jmp @nobankswitch
   
        {code for changing bank}
        @changeBank:
        push ax
        push bx
        mov ax, $4F05
        xor bx, bx
        mov dx, gran
        inc dx
        mov gran, dx
        int $10
        pop bx
        pop ax
        {set to begining of buffer and copy remaining bytes}
        mov di,0
        rep movsb
        pop cx
        jmp @nobankswitch

        {normal copy of row data}
        @normalcopy:
        shr cx, 1

        rep movsw

        jnc @even
        movsb
        @even:
        pop cx
        {check if we will cross the bank boundary going to next row}
        mov dx, di
        add dx, 640
        sub dx, wsize
        cmp dx, 640
        ja @nobankswitch
        push ax
        push bx
        mov ax, $4F05
        xor bx, bx
        mov dx, gran
        inc dx
        mov gran, dx
        int $10
        pop bx
        pop ax
        sub di, wsize
        @nobankswitch:
        {update si and di for next row}
        add di, 640
        sub di, ax
        {update si using bx for when the image is clipped on the right side}
        add bx, width
        mov si,bx
        loop @startrow
        pop ds
     end;
     cgran:= gran;
end;

{puts an image to the screen, XORs it with what's already on screen.}
{ could be easily modified to do AND or NOT as well }
procedure putImageXOR(x,y : word; bitmap : pointer);
var
   bseg,bofs   : word;
   tseg,tofs   : word;
   i	       : word;
   sizex,sizey : word;
   width       : word;
begin
   if checkBounds(x,y) then exit;
   bseg := seg(bitmap^);
   bofs := ofs(bitmap^);
   tseg := cardseg; {store the target buffer/screen segment and ofset on the stack}
   tofs := 0;
   sizex := memw[bseg:bofs];
   sizey := memw[bseg:bofs+2];
   width := sizex;
   if (x+sizex>319) then
      sizex := 320-x;
   if (y+sizey>199) then
      sizey := 200-y;
   asm
       push ds
       {set direction flag}
       cld
       {load the counter with the number of rows}
       mov cx, sizey
       { set up the segment registers }
       mov ax,tseg
       mov es,ax
       mov ax,bseg
       mov ds, ax
       {set up the input ofset }
       mov ax, bofs
       add ax, 4
       mov si, ax
       mov bx, ax
       { load the initial row offset for the output buffer}
       mov ax, y
       mov dx, 320
       mul dx
       add ax, x
       add ax, tofs
       mov di, ax
       mov dx, sizex
   {at this point cx - number of rows, dx pixels per row (might be smaller)
    bx image ofset (start of row) 
    es:di screen/buffer pointer ds:si image pointer }
   {start processing each row source ds:si to es:di}
   @startrow:
       {set up a counter for the number of words}
       push cx {save cx for later}
       mov cx,dx  {put the number of pixels in cx}
       shr cx,1   {div by two as we work by words}

       {jump if zero, no words perhaps a single byte to copy}
       jz @skip
   
       {copy the words whilst doing xor operation}
   @xorword:
       mov ax, [es:di]
       xor ax, [ds:si]
       stosw
       add si,2  {si isn't incremented so do that}
       loop @xorword {loop if more words need to be done}

       {restore cx then figure out if dx is even or odd}
   @skip:
       pop cx
       mov ax,dx
       shr ax,1

       jnc @even
       {copy the last odd byte}
       mov al, [es:di]
       xor al, [ds:si]
       stosb
   
   @even:
   {ok the row should be copied we just need to change the ofsets for the next row.}
       {update screen/buffer ofset}
       add di,320
       sub di,dx
       {update si}
       add bx, width
       mov si, bx
       loop @startrow
   
       {ok we should be done, restore the data segment}
       pop ds
   end;   
end;

procedure circle(x,y,radius: word; colour: byte);
{circle algorithm from SWAG that uses integers}
{this is quite slow because it uses putpixel, Since I don't need this so much it won't be optimised}
var
   a, af, b, bf,
   target, r2 : word;
begin
     if checkVBounds(x,y) then exit;
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
              af:= ((a * 3) div 4);
	      bf:= ((b * 3) div 4);
                
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
end.
