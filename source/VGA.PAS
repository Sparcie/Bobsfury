{ A Basic mode $13 VGA graphics unit for the purposes of
  comparing a hand written VGA interface to the BGI Graph
  unit commonly included with Turbo Pascal. It's not
  designed to be as fast as possible, but it should be quick
  enough for the purposes of comparison.

  This version has been optimised in assembly partly, but
  I'm sure it could be done faster if you really want.

  I've used fixed point math so it should run ok on 286 and 386
  machines without a FPU.

  A Danson 2015

  Modified for use with Bob's Fury 2021- 
  including adding some features needed for the game.
  added drawing with XOR for images
  and options for drawing to an of screen buffer.
 }

unit vga;

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

{procedures for setting up and using the back buffer}
function setDrawMode(m : byte):boolean;
{0 - draw to screen memory (no back buffer) , 1 - enable back buffer (draw to it by default), 
 2 - enable back buffer but draw to screen }
procedure copyToScreen; {flush back buffer to screen}
procedure copyToBuffer; {copy screen to back buffer}
{copy a portion of the screen/buffer. dir = true copy from screen -> buffer dir=false copy from buffer -> screen}
procedure copySegment(x,y,sizex,sizey : word; dir : boolean);

implementation

uses fixed,gcommon;

const
     cardSeg = $A000;
     cardofs = $0000;		     

var
   inited     : boolean; {have we started the display?}
   exitSave   : pointer;
   targseg    : word;
   targofs    : word;
   backbuffer : pointer;   
   mode	      : byte;


{basic start-up and shutdown}
procedure init;
begin
     if (inited) then exit;
     asm
         mov ax, $0013
        int $10
     end;
     inited := true;
     mode := 0;
     targseg := cardseg;
     targofs := cardofs;
     exitSave := exitproc;
     exitproc := @shutdown;
     fillmem(cardseg,0,0,64000);
end;
procedure cls;
begin
   fillmem(targseg,targofs,0,64000);
end;

{$f+}
{shutdown procedure - return to text mode}
procedure shutdown;
begin
     if not(setDrawMode(0)) then exit;
     if not(inited) then exit;
     asm  {the small amount of assembler I will use}
        mov ax, $0003
        int $10
     end;
     inited := false;
     exitproc := exitsave;
end;
{$f-}

{basic drawing stuff - lines and boxes}


{line drawing routine, using bresenhams line algorithm}
procedure line(x,y,x1,y1: word; c: byte);
var
   count,xs,ys,xm,ym:integer;
   cx,cy: word;
begin
    if checkBounds(x,y) then exit;
    if checkBounds(x1,y1) then exit;    
    cx := x; cy := y * 320;
    xs := x1 - x; ys := y1 - y;

    xm:= sign(xs); ym := sign(ys) * 320;
    xs := abs(xs); ys := abs(ys);

    mem[targseg:targofs + cx + cy] := c;
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
            mem[targseg:targofs + cx + cy] := c;
        end;
    end
    else
    begin
         count := -(ys shr 1);
         y1 := y1 * 320;
         while (cy <> y1) do
         begin
             count := count + xs;
             cy := cy + ym;
             if count>0 then
             begin
                  cx:=cx + xm;
                  count := count - ys;
             end;
             mem[targseg: targofs + cx + cy] := c;
         end;
    end;
end; 

{filled box routine}
procedure filledBox(x,y,x1,y1: word; c : byte);
begin
   if checkBounds(x,y) then exit;
   if checkBounds(x1,y1) then exit;
   if (x>x1) then
   begin
      swapW(x,x1);
   end;
   if (y>y1) then
   begin
      swapW(y,y1);
   end;
   asm
       {load the destination pointer}
       mov bx, targseg
       mov es, bx

       mov ax, y
       mov bx, 320
       mul bx
       add ax, x
       add ax, targofs
       mov di, ax

       {set up bx with the width of the box}
       mov bx, x1
       sub bx, x
       add bx, 1

       {set up cx to count the number of rows}
       mov cx, y1
       sub cx, y
       add cx, 1

       {load the AX register with the word data}
       mov al, c
       mov ah, al

       {set the direction}
       cld

       {loop and copy the data!}
       @row:
       push cx
       mov cx, bx
       shr cx, 1 {divide cx by two to copy words}

       {copy the accumulator to memory repeatedly}
       rep stosw

       jnc @even
       stosb
       @even:

       {end loop - work out next start point}
       add di, 320
       sub di, bx
       pop cx
       loop @row
   end;
end;

{put pixel routine, not the fastest way to draw}
procedure putPixel(x,y : word; c : byte);
begin
    if checkBounds(x,y) then exit;
    mem[targSeg: targofs + x + (y*320)] := c;
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
   tseg,tofs   : word;
   sizex,sizey : word;
begin
     if checkBounds(x,y) then exit;
     if checkBounds(x1,y1) then exit;
     bseg := seg(bitmap^);
     bofs := ofs(bitmap^);
     tseg := targseg;
     tofs := targofs;
     if x>x1 then swapw(x,x1);
     if y>y1 then swapw(y,y1);
     sizex := (x1-x) + 1;
     sizey := (y1-y) + 1;
     memw[bseg:bofs] := sizex;
     memw[bseg:bofs+2] := sizey;
     {replacing the above with assembly!}
     asm
        push ds
        {set direction}
        cld
        {set up the counters for the loop}
        mov cx, sizey

        {set up the segment pointers}
        mov ax, tseg
        mov ds, ax
        mov ax, bseg
        mov es, ax
        {set up the destination offset}
        mov ax, bofs
        add ax, 4
        mov di, ax
        {work out the first row starting ofset}
        mov ax, y
        mov dx, 320
        mul dx
        mov si, tofs
        add si, ax
        add si, x

        mov ax, sizex

        {start of the loop}
        @startrow:
        {do the transfer}
        push cx
        mov cx,ax
        shr cx, 1

        rep movsw

        jnc @even
        movsb
        @even:

        pop cx
        {update si for next row}
        add si, 320
        sub si, ax
        loop @startrow
        pop ds
     end;
end;

{puts an image to the screen, is a direct copy}
procedure putImage(x,y : word; bitmap : pointer);
var
   bseg,bofs   : word;
   tseg,tofs   : word;
   i	       : word;
   sizex,sizey : word;
   width       : word; {copy of the width for updating the source ofset}
begin
     if checkBounds(x,y) then exit;
     bseg := seg(bitmap^);
     bofs := ofs(bitmap^);
     tseg := targseg;
     tofs := targofs;
     sizex := memw[bseg:bofs];
     width := sizex;
     sizey := memw[bseg:bofs+2];
     if (x+sizex>319) then
        sizex := 320-x;
     if (y+sizey>199) then
        sizey := 200-y;
     {replaced pascal loop with assembly!}
     asm
        push ds
        {set direction}
        cld
        {set up the counters for the loop}
   
        mov cx, sizey
   
        {set up the segment pointers}
        mov ax, tseg
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
        mov ax, y
        mov dx, 320
        mul dx
        add ax, x
        add ax, tofs
        mov di, ax
        mov ax, sizex

        {start of the loop}
        @startrow:
        {do the transfer}
        push cx
        mov cx,ax
        shr cx,1

        rep movsw

        jnc @even
        movsb
        @even:

        pop cx
        {update si and di for next row}
        add di, 320
        sub di, ax
        {update si using bx for when the image is clipped on the right side}
        add bx, width
        mov si,bx
        loop @startrow
        pop ds
     end;
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
   tseg := targseg; {store the target buffer/screen segment and ofset on the stack}
   tofs := targofs;
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
var
   a, af, b, bf,
   target, r2 : word;
   yofs : word; {the y offset into the vga memory}
   clip : boolean;
begin
     if checkBounds(x,y) then exit;
     clip := false;
     if (x< radius) or (y<radius) then clip :=true;
     if (319-x<radius) or (199-y<radius) then clip := true;
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
              af:= ((a * 3) div 4) * 320 ;
              bf:= ((b * 3) div 4) * 320 ;
              yofs := (y * 320) + targofs ;

              {optimise the drawing with asm if not going off the screen}
	      if not(clip) then
              asm
                 {set up the es:di initial value}
                 mov ax, targseg
                 mov es, ax
                 mov ax, x
                 add ax, yofs
                 mov di, ax
                 mov bx, ax  {store in bx for later use as well.}
                 mov cx, a   {store a in cx to reduce memory usage}
                 mov dx, b   {store b in dx for the same reason}
                 {put the colour in al}
                 mov al, colour
                 {draw +a +bf}
                 add di, cx
                 add di, bf
                 mov [es:di], al
                 mov di, bx
                 {draw +b +af}
                 add di, dx
                 add di, af
                 mov [es:di], al
                 mov di, bx
                 {draw -a +bf}
                 sub di, cx
                 add di, bf
                 mov [es:di], al
                 mov di, bx
                 {draw -b +af}
                 sub di, dx
                 add di, af
                 mov [es:di], al
                 mov di, bx
                 {draw -a -bf}
                 sub di, cx
                 sub di, bf
                 mov [es:di], al
                 mov di, bx
                 {draw -b -af}
                 sub di, dx
                 sub di, af
                 mov [es:di],al
                 mov di, bx
                 {draw +a - bf}
                 add di, cx
                 sub di, bf
                 mov [es:di], al
                 mov di, bx
                 {draw +b - af}
                 add di, dx
                 sub di, af
                 mov [es:di],al
              end;

	      if clip then
	      begin
		 putpixel(x+a,y+bf,colour);
		 putpixel(x+b,y+af,colour);
		 putpixel(x-a,y+bf,colour);
		 putpixel(x-b,y+af,colour);
		 putpixel(x-a,y-bf,colour);
		 putpixel(x-b,y-af,colour);
		 putpixel(x+a,y-bf,colour);
		 putpixel(x+b,y-af,colour);
	      end;
              inc(b);
          end;
          dec(a);
     end;
end;

function setDrawMode(m : byte):boolean;
begin
   setDrawMode := false;
   if not(inited) then exit;
   if ((mode=0) and (m>0)) then
   begin
      if maxavail<64000 then exit; {not enough memory to change to another mode!}
      setDrawMode := true;
      getmem(backbuffer, 64000);
      fillmem(seg(backbuffer^),ofs(backbuffer^),0,64000);
      mode := m;
   end;
   if ((mode>0) and (m=0)) then
   begin
      setDrawMode := true;
      freemem(backbuffer,64000);
      mode := m;
      targseg := cardseg;
      targofs := cardofs;
      exit;
   end;
   setDrawMode := true;
   mode:=m;
   if (m=1) then
   begin
      targseg := seg(backbuffer^);
      targofs := ofs(backbuffer^);
   end;
   if (m=2) then
   begin
      targseg := cardseg;
      targofs := cardofs;
   end;
end;

procedure copyToScreen; {flush back buffer to screen}
begin
   if mode = 0 then exit;
   copymem(seg(backbuffer^),ofs(backbuffer^),cardseg,cardofs,64000);
end;

procedure copyToBuffer; {copy screen to back buffer}
begin
   if mode = 0 then exit;
   copymem(cardseg,cardofs,seg(backbuffer^),ofs(backbuffer^),64000);
end;

procedure copySegment(x,y,sizex,sizey : word; dir : boolean);
var
   sseg,sofs : word;
   tseg,tofs : word;
begin
   if checkBounds(x,y) then exit;
   if checkBounds(x+sizex-1,y+sizey-1) then exit;
   if dir then
   begin
      sseg:= cardseg;
      sofs:= cardofs;
      tseg:=seg(backbuffer^);
      tofs:=ofs(backbuffer^);
   end
   else
   begin
      tseg:= cardseg;
      tofs:= cardofs;
      sseg:=seg(backbuffer^);
      sofs:=ofs(backbuffer^);
   end;
   asm
      push ds
      {calculate the starting ofset into screen/buffer and store in bx}
      mov ax,y
      mov dx,320
      mul dx
      add ax,x
      mov bx,ax
      {load source pointer}
      mov ax, sseg
      mov ds, ax
      mov si, bx
      add si, sofs
      {load destination pointer}
      mov ax, tseg
      mov es, ax
      mov di, bx
      add di, tofs
      {load counter with the number of rows bx with width}
      mov cx, sizey
      mov bx, sizex
      {set direction register}
      cld

   @row:
      push cx
      mov cx,bx
      shr cx,1

      rep movsw

      jnc @even
      movsb
   @even:
      pop cx
      {update the pointers for the next row}
      add si,320
      sub si,bx
      add di,320
      sub di,bx
      loop @row
      

      pop ds
   end;
end;

begin
     inited := false;
     mode :=0;
end.
