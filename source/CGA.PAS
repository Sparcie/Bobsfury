{ 
  CGA Graphics unit made for Bob's fury as part of a replacement for
  the BGI. Same interface as the VGA unit so it's easy to use them
  interchangably.
  
  A Danson 2022
 }

unit cga;

interface

{basic start-up and shutdown}
procedure init;
procedure shutdown;
procedure cls;

{CGA only function for setting palette }
{ $1  is intensity 
  $2  is the palette 
  pal is the palette
  backg is the background colour}
procedure CGAPalette(pal, backg: byte );


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
     cardSeg = $B800;
     cardofs = $0000;
     startMask : array[0..3] of byte = ($FF, $3F, $0F, $03); {position 0 indicates mask not needed!}
     endMask: array[0..3] of byte = ( $C0, $F0, $FC, $FF);  {position 3 indicates mask not needed!}
     
var
   inited	   : boolean; {have we started the display?}
   exitSave	   : pointer;
   backBuffer	   : pointer;
   targseg,targofs : word;
   mode		   : byte;
   lastmode	   : byte;


{basic start-up and shutdown}
procedure init;
begin
     if (inited) then exit;
     asm
        mov ax, $0f00
        int $10
        mov lastmode, al
        mov ax, $0004
        int $10
     end;
     targseg := cardseg;
     targofs := cardofs;
     inited := true;
     mode := 0;
     cls;
end;

procedure cls;
begin
   fillmem(targseg,targofs, 0, 16384);
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
var
   b : boolean;
begin
     b := setDrawMode(0);
     asm  {back into text mode}
        mov ah, $00
        mov al, lastmode
        int $10
     end;
     inited := false;
end;

{CGA only function for setting palette }
{ $1  is intensity 
  $2  is the palette 
  pal is the palette
  backg is the background colour}
procedure CGAPalette(pal, backg: byte );
var
        colourControl : byte;
        temp : word;
const
        background : array[0 .. 15] of byte = ( $00, $01, $02, $03, $04, $05, $06, $07,
        $38, $39, $3A, $3B, $3C, $3D, $3E, $3F);
        foreground : array[0 .. 3, 0 ..2] of byte = ( ($02, $04, $06), ($3a, $3c, $3e),
                                            ($03, $05, $07), ($3b, $3d, $3f));
begin
        {do the CGA registers}
        port[$03d8] := $A;
        colourControl := (pal shl 4) or backg;
        port[$03d9] := colourControl;
        
        {modify palette for ega/vga so they look correct}
        temp := $100 * background[backg];
        asm
                mov ax, $1000
                mov bx, temp
                int $10
        end;
        
        for colourControl := 0 to 2 do
        begin
                temp := $100 * foreground[pal,colourControl] + 1 + colourControl;
                asm
                        mov ax, $1000
                        mov bx, temp
                        int $10
                end;
        end;
end;

{basic drawing stuff - lines and boxes}

{this function takes a colour and returns a byte that would draw to all pixels in a byte}
function fillByte( c: byte):byte; assembler;
asm
    mov al, c
    and al, $03
    mov ah, al
 
    shl al, 1
    shl al, 1
    or al, ah
 
    shl al, 1
    shl al, 1
    or al, ah
 
    shl al, 1
    shl al, 1
    or al, ah
 
    xor ah, ah 
end;

{this function calculates the buffer offset for a screen position (includes targofs) }
function screenOfset(x, y :  word):word; assembler;
asm
   {we're implementing
     tofs := (x div 4) + (80 * (y shr 1)) + targofs;
     if y and 1 = 1 then tofs := tofs + $2000; set the correct bank
   in assembly. }
   mov bx, x {using BX to store the x component}
   shr bx,1 {divide by 2 twice to divide by 4}
   shr bx,1
   mov cx, y    { using cx to calculate with the y component, will store the accumulated value in ax }
   shr cx,1     {test if we need bank 0 or 1}
   jc @bank1
   xor ax,ax
   jmp @bankdone
@bank1:
   mov ax, $2000
@bankdone:
{now we need to multiply what's left in cx by 80. We can do this with some shifting and adding fortunately}
   shl cx,1
   shl cx,1
   shl cx,1
   shl cx,1
   add ax, cx   
   shl cx,1
   shl cx,1
   add ax, cx
   {now add the x to the value so far}
   add ax, bx
   {add the value of targofs (in case it's not screen memory}
   add ax, targofs
end;
			  

{line drawing routine, using bresenhams line algorithm}
procedure line(x,y,x1,y1: word; c: byte);
var
   xs,ys,ym : integer;
   ofs	    : word;
   nr	    : integer;
begin
    if checkBounds(x,y) then exit;
    if checkBounds(x1,y1) then exit;

    c := fillByte(c);
   
    {make the lines always left to right}
    if (x1<x) then
    begin
       swapW(x,x1);
       swapW(y,y1);
    end;

    {determine starting ofset}
    ofs := screenOfset(x,y);
       
    xs := Integer(x1) - x; ys := Integer(y1)-y;

    ym := sign(ys) * 80;
    xs := abs(xs); ys := abs(ys);

    {to move up/down a row we need to know whether to increment or decrement or just change bank}
    { the nr (si register) stores what to do on the next row change, it contains ym or zero to add to the ofset }
    { after moving a row we just xor ym into the register to know what to do next, but we need to determine}
    { it's initial state: this next short segment determines it's initial state.
    The bank ofset is already in the ofset variable.} 
   nr := 0; {initial state for sanity}
   if (y and 1) = 1 then
    begin {we're on the odd bank}
       if ym<0 then nr := 0; { going from odd to even (up) doesn't change ofset }
       if ym>0 then nr := ym; { going from odd to even (down) does change ofset }
    end
    else
    begin {we're on the even bank}
       if ym<0 then nr := ym; {going from even to odd (up) does change ofset}
       if ym>0 then nr := 0;  {going from even to odd (down) doesn't change ofset}
    end;    
   
    if xs > ys then
    begin
       {assembly replacement of the line drawing segment.}
       { ES:DI pointer to current draw location }
       { SI - stores the amount we need to increment for the next row }
       { AX - contains the error variable for bresenham }
       { BH contains masking for the current pixel we're working on }
       { CX contains current horizontal location }
       { DL stores the current graphic byte from CGA memory }
       { DH stores a copy of the colour (filling all pixels)}
       asm
           {set up the registers
            first load the segment/offset }
           mov ax, targseg
           mov es, ax
           mov di, ofs
           {load our next row data}
           mov si, nr
           {initialise the mask for the current pixel location }
           mov bh, $C0
           mov cx, x
           and cx, $3
           jz @xskipshift
       @xshift:
           shr bh,1
           shr bh,1
           loop @xshift
       @xskipshift:
           {load the colour byte and byte from CGA }
           mov dl,[ES:DI]
           mov dh,c
           {draw the first pixel into the byte loaded}
           not bh      {invert the mask}
           and dl, bh  {so we can mask out the pixel to draw into}
           not bh      {restore the mask}
           mov bl, dh  {load bl with the colour}
           and bl, bh  {mask of the pixels we aren't drawing}
           or dl, bl   {put the pixel data into the register storing the current byte}
           { the byte won't be written back to the CGA until we change rows, finish the byte or the line }
           { put the number of line pixels to draw in cx }
           mov cx, xs
           or cx, cx {check if the count is zero!}
           jz @xskipline {skip line drawing if there are zero pixels to draw}
           {initialise the count variable (it stores the error for the bresenham algorithm.)}
           xor ax, ax
           sub ax, xs
           sar ax, 1

           {the drawing loop }
       @xstart:
           {shift to the next pixel}
           shr bh, 1 
           shr bh, 1
           {check if we've completed a byte}
           jnz @xcheckrow {if we're part way through go to the row check}
           {byte complete - write it back to the CGA and set up for the next byte}
           mov [es:di], dl
           inc di
           mov dl, [es:di]
           mov bh, $C0       
       @xcheckrow:
           {now we need to check if we need to move up/down a row}
           add ax, ys
           cmp ax, 0
           jl @xaddpixel
           {ok we need to move up/down a row}
           mov [es:di], dl {write graphics byte back to cga}
           {update ax (error number)}
           sub ax, xs
           {add enough bytes for a row}
           add di, si {add the possible ofset change}
           xor di, $2000 {change bank}
           xor si, ym  {update the change register for next row (opposite of what it is now, either 0 or ym)}
           mov dl, [es:di] {get the next graphics byte to update}
       @xaddpixel:
           {add a pixel to the byte stored in dl}
           not bh      {invert the mask}
           and dl, bh  {so we can mask out the pixel to draw to}
           not bh      {restore the mask}
           mov bl, dh  {load bl with the colour byte}
           and bl, bh  {mask of pixels we aren't drawing}
           or dl, bl   {put the pixel data into the register}
           {figure out if we're finished.}
           loop @xstart
       @xskipline:
           mov [ES:DI], dl {write the graphic byte in case it wasn't written}
       end;
    end
    else
    begin
       {assembly replacement of mostly vertical line drawing}
       { ES:DI pointer to current draw location}
       { SI - stores the amount we need to increment for the next row }
       { AX - contains the error variable for bresenham }
       { BH - contains masking for the current pixel }
       { CX - contains the count of pixels vertically to draw }
       { DL - stores the current graphic byte from CGA memory  }
       { DH - stores a copy of the colour (filling all pixels) }
       asm
            {set up registers}
            {load colour byte}
            mov dh, c
            {load pointer to first pixel}
            mov ax, targseg
            mov es, ax
            mov di, ofs
            {load the si register from nr}
            mov si, nr
            {initialise mask for current pixel location}
            mov bh, $C0       
            mov cx, x
            and cx, $3
            jz @yskipshift
       @yshift:
            shr bh, 1
            shr bh, 1
            loop @yshift
       @yskipshift:
            {initialise the ax error variable}
            xor ax,ax
            sub ax, ys
            sar ax, 1
            {load the count vertical pixels}
            mov cx, ys
            {draw the first pixel}
            mov dl, [es:di] {load the data}
            not bh          {invert mask}
            and dl, bh      {mask pixels we aren't drawing}
            not bh          {restore mask}
            mov bl, dh      {copy the colour byte}
            and bl, bh      {mask the colour byte}
            or dl, bl       {add colour to pixel we're drawing}
            mov [es:di], dl {write back to the CGA}
            {check if the line length is zero (and skip!)}
            or cx,cx {update flags}
            jz @yskipline {skip if amount is zero}
            
       @ystart:
            {adjust the error variable}
            add ax, xs
            {go to next row up or down}
            add di, si {adjust ofset if needed}
            xor di, $2000 {switch bank}
            xor si, ym {update the change register for next row (opposite of it's current state, either 0 or ym) }
       
            {check if we need to move right one pixel}
            cmp ax,0
            jl @ydrawpixel
            {move right a pixel}
            sub ax, ys {update error value}
            {shift the mask}
            shr bh, 1
            shr bh, 1
            jnz @ydrawpixel
            mov bh, $C0 {if we've moved to the next byte}
            inc di
       @ydrawpixel:
            {having updated things draw the pixel.}
            mov dl, [es:di] {get byte from CGA}
            not bh          {invert mask}
            and dl, bh      {mask off pixel to draw}
            not bh          {restore mask}
            mov bl, dh      {copy colour byte}
            and bl, bh      {mask colour data for pixel}
            or dl, bl       {add colour data to pixel being drawn}
            mov [es:di], dl {write byte back to CGA}
            loop @ystart    {loop if we have more to draw}
       @yskipline:
       end;
    end;
end;

{filled box routine}
procedure filledBox(x,y,x1,y1: word; c : byte);
var
   rowByte : byte; {byte that would draw all 4 pixels }
   maskS, maskE : byte; { mask for the start and end of the row }
   rowLength : word; {bytes to direct copy between start and end}
   oByte : byte; {set to $00 to skip to end because there is only one byte to write}
begin
   if checkBounds(x,y) then exit;
   if checkBounds(x1,y1) then exit;
   if (x>x1) then
      swapW(x,x1);
   if (y>y1) then
      swapW(y,y1);
   rowByte := fillbyte(c);
   maskS := startMask[x and $3];
   maskE := endMask[x1 and $3];
   rowLength := (x1 shr 2) - (x shr 2) - 1;
   oByte := $FF;
   if rowLength=$FFFF then
   begin
      maskS := maskS and maskE;
      oByte:=0;
      rowLength := 0;
   end;
   asm
       {calulate ofset}
       push x
       push y
       call screenOfset
       mov di, ax
       {load segment}
       mov bx, targseg
       mov es,bx

       {CL will store the value which will determine if
       the offset is incremented for the next row}
       mov cl, 80
       mov ax,y
       shr ax,1
       jnc @even
       xor cl, cl
   @even:       
       { ok ofset is set up in ES:DI and CX contains a value for incrementing the ofset (for changing rows)}
       mov dl, cl {move the value for incrementing the row to DL as I will need CX}
       mov cx, y1 {calculate number of rows and store in CX}
       sub cx, y
       inc cx
       mov bh, maskS  {put the start mask in BH and the end mask in BL}
       mov bl, maskE
       mov dh, rowByte {put the colour byte in DH}

   @startRow: {start of drawing rows!}

       {draw the pixels in the leading byte}
       mov al, [es:di] {get the pixels}
       mov ah, bh { use mask to keep pixels we need }
       not ah
       and al, ah
       mov ah, dh { use mask to draw new pixels }
       and ah, bh
       or al, ah
       mov [es:di], al {write back to screen}
       inc di
       {check if this is going to be a single byte}
       mov al, oByte
       or al,al
       jz @oneByte

       {ok we should be doing the intermediate pixels, whole bytes!}
       mov al, dh
       mov ah, dh
       push cx {we will need cx later}
       mov cx, rowLength
       shr cx, 1

       rep stosw
       jnc @skipByte
       stosb
    @skipByte:
       pop cx

       {ok now we need to draw the tail pixels for the row}
       mov al, [es:di] {get the pixels}
       mov ah, bl {use mask to keep pixels we need}
       not ah
       and al, ah
       mov ah, dh {use mask to draw new pixels}
       and ah, bl
       or al, ah
       mov [es:di], al

       {ok we should have now completed a row, update the ofset as needed}
    @oneByte:
       xor dl, 80 { toggle the row increment (because of bank switching }
       xor dh, dh
       add di, dx {adjust offset}
       sub di, rowLength
       dec di
       xor di, $2000 {switch CGA bank}
       mov dh, rowByte {restore this value (had to be erases to inc di)}

       loop @startRow {do the next row}

   end;
end;

{put pixel routine, not the fastest way to draw}
procedure putPixel(x,y : word; c : byte);
begin
    if checkBounds(x,y) then exit;
    c := c and $3;
    asm {assembly implementation}
       {calulate ofset (have a function for it)}
       push x
       push y
       call screenOfset
       mov di,ax   
       {load segment}
       mov bx, targseg
       mov es,bx
       {set up mask and colour and shift them}
       mov bl, c
       mov bh, $03
       mov cx, x
       not cx
       and cx, $0003
       jz @noshift
   @shift:
       shl bx,1
       shl bx,1
       loop @shift
   @noshift:
       {get pixel}
       mov al, [es:di]
       {apply mask then pixel}
       not bh
       and al,bh
       or al, bl
       {write byte back}
       mov [es:di],al   
    end;
end;

{basic blitting stuff - get and put in gwbasic terms}
{this will tell you how much memory to allocate to a
 pointer for a given screen area}
function imageSize(sx,sy:word):word;
begin
     imageSize := ((sx div 4) + 2  ) * 4 * sy + 4;
end;

{gets an image and stores it in a chunk of memory, be sure to allocate enough memory}
procedure getImage(x,y,x1,y1 : word; bitmap : pointer);
var
   bseg,bofs   : word;
   sseg,sofs   : word;
   i,c	       : word;
   sizex,sizey : word;
   rowSize     : word;
   buffwidth   : word;
   pixels      : word;
   shift       : byte;
begin
   if checkBounds(x,y) then exit;
   if checkBounds(x1,y1) then exit;
   bseg := seg(bitmap^);
   bofs := ofs(bitmap^);
   if x1<x then swapW(x,x1);
   if y1<y then swapW(y,y1);
   sizex := (x1 - x) + 1;
   sizey := (y1 - y) + 1;
   fillmem(bseg, bofs, 0, imageSize(sizex, sizey));
   rowSize := (sizex div 4) + 1;
   buffwidth := rowSize + 1;
   memw[bseg:bofs] := sizex;
   memw[bseg:bofs+2] := sizey;
   bofs := bofs + 4; {set to begining of buffer}
   shift := (x mod 4) * 2;
   {figure out the starting address from the source}
   sseg := targseg;
   sofs := screenOfset(x,y);
   
   { ok now we should be ready to get the image from the screen image}
   { we're going to copy each bank separately so as to save time in drawing}
   
   i:=0;
   while (i < ((sizey shr 1) + (sizey and 1)) ) do
   begin
      c:=0;
      while (c<sizex) do
      begin
         pixels := memw[sseg:sofs];
         pixels := swap(pixels) shl shift; {because the endianness swaps the pixel bytes}
         mem[bseg:bofs] := hi(pixels);
         inc(bofs);
         inc(sofs);
         c:= c + 4;
      end;
      {we need to mask off the pixels on the tail of each row}
      dec(bofs); {go back to that byte }
      if sizex mod 4 > 0 then
         mem[bseg:bofs] := mem[bseg:bofs] and endMask[ (sizex mod 4) - 1 ];
      inc(bofs);
      inc(bofs); {skip the padding byte that will be needed for later copies of the image }
      inc(i);
      { adjust the ofset of the input - the buffer offset should be correct }
      sofs := sofs - rowsize + 80;
   end;
   
   {ok now copy the other bank}
   {reset source ofset}
   sofs := (x div 4) + (80 * (y shr 1)) + targofs;
   if y and 1 = 0 then sofs := sofs or $2000; {set the correct bank (opposite of the first one}

   i:=0;
   while (i < (sizey shr 1)) do 
   begin
      c:=0;
      while (c<sizex) do
      begin
         pixels := memw[sseg:sofs];
         pixels := swap(pixels) shl shift; {because the endianness swaps the pixel bytes}
         mem[bseg:bofs] := hi(pixels);
         inc(bofs);
         inc(sofs);
         c:= c + 4;
      end;
      {we need to mask off the pixels on the tail of each row}
      dec(bofs); {go back to that byte }
      if sizex mod 4 > 0 then
         mem[bseg:bofs] := mem[bseg:bofs] and endMask[ (sizex mod 4) - 1 ];
      inc(bofs);
      inc(bofs); {skip the padding byte that will be needed for later copies of the image }
      inc(i);
      { adjust the ofset of the input - the buffer offset should be correct }
      sofs := sofs - rowsize + 80;
   end;


   i:=0;
   while (i < ((sizey shr 1) + (sizey and 1)) ) do
   begin
      c:=0;
      while (c<sizex) do
      begin
         pixels := memw[sseg:sofs];
         pixels := swap(pixels) shl shift; {because the endianness swaps the pixel bytes}
         mem[bseg:bofs] := hi(pixels);
         inc(bofs);
         inc(sofs);
         c:= c + 4;
      end;
      {we need to mask off the pixels on the tail of each row}
      dec(bofs); {go back to that byte }
      if sizex mod 4 > 0 then
         mem[bseg:bofs] := mem[bseg:bofs] and endMask[ (sizex mod 4) - 1 ];
      inc(bofs);
      inc(bofs); {skip the padding byte that will be needed for later copies of the image }
      inc(i);
      { adjust the ofset of the input - the buffer offset should be correct }
      sofs := sofs - rowsize + 80;
   end;


   {ok now we need to make the pre-shifted copies so that we don't have to do the shifting at draw time}
   i:=1;
   while (i<4) do
   begin
        { reset the source segment and offset to the image we have in the buffer }
        sseg := seg(bitmap^);
        sofs := ofs(bitmap^) + 4;
        { the bseg variable is already set up so we only need to set the destination ofset }
        bofs := ofs(bitmap^) + 4 + ( i * (buffwidth * sizey));
        { copy and shift the bytes into the image copy }
        c:=0;
        shift := 0;
        while (c < ( buffwidth * sizey)) do
        begin
                pixels := mem[sseg: sofs];
                pixels := swap(pixels) shr ( i * 2);
                mem[bseg: bofs] := hi(pixels) or shift;
                shift := lo(pixels);
                inc(c);
                inc(sofs);
                inc(bofs);
        end;
        inc(i);
   end;    
end;

{puts an image to the screen, is a direct copy}
procedure putImage(x,y : word; bitmap : pointer);
var
   bseg,bofs   : word;
   tseg,tofs   : word;
   sizex,sizey : word;
   bwidth      : word; { width of the buffer }
   width       : word; { width of section to copy }
   maskS,maskE : byte; {mask for begining and end}
begin
     if checkBounds(x,y) then exit;
     bseg := seg(bitmap^);
     bofs := ofs(bitmap^);
     tseg := targseg;
     tofs := screenOfset(x,y);

     sizex := memw[bseg:bofs];
     sizey := memw[bseg:bofs+2];
     bwidth := (sizex shr 2) + 2;
     {adjust the ofset of the buffer to the already shifted copy}
     bofs := bofs + 4 + ((x and $3) * bwidth * sizey);
     if (x+sizex>319) then
        sizex := 320-x;
     if (y+sizey>199) then
        sizey := 200-y;
     width := ((sizex + (x and $3)) shr 2); {in bytes that are to be copied before the end}
     maskS := not startMask[x and $3];
     maskE := not endMask[ (x + sizex -1) and $3 ];
     {check if we really need the end byte/mask}
     if maskE = $FF then
     begin
        maskE :=0;
        inc(width);
     end;
     if ((x shr 2) + width > 80) then
     begin
        width := 80 - (x shr 2); {check if we only need the first byte due to edge of screen }    
        maskE := 0;
     end;
     { AX will be for working - loading pixel bytes and manipulating them
       BX the width variable (how many bytes to transfer per row)
       CX Row and byte counter 
       DH start mask
       DL end mask
       DS:SI pointer to image buffer (source)
       ES:DI pointer to screen/backbuffer (destination }
     asm
        push ds
        {load segment registers (both)}
        mov ax, bseg
        mov ds, ax
        mov ax, tseg
        mov es, ax
        {load ofset for image buffer}
        mov ax, bofs
        mov si, ax
        {load the screen ofset}
        mov ax, tofs
        mov di, ax
        {ok ofsets and segments are done, load the row counter and other registers with initial values}
        mov cx, sizey
        shr cx,1
        jnc @noExtra
        inc cx
     @noExtra: 
        mov dh, maskS
        mov dl, maskE 
       
     @firstbank: {draw all the rows in the first bank from the buffer}
        { write first byte using mask }
        mov ah, [es:di]  {load pixels from screen}
        mov al, [ds:si]  {load image buffer pixels }
        and ah, dh	 {mask pixels we need}
        or al, ah        {or these with those from buffer}
        mov [es:di], al  {write to screen}
        
        mov bx, width
        or bx, bx        { check if width = 0 and skip further drawing }
        jz @skip
        inc di           {increment offsets }
        inc si
        xchg bx, cx     {swap cx and bx (so as to save the row count but use cx for string copy)}
        dec cx           { already done the start byte so update counter }

        rep movsb       {copy pixel bytes from image buffer to screen if needed}
        
        xchg bx, cx     {swap them back so as to save the row counter back to cx}

        {write last byte}
        or dl, dl {test if we need a last byte}
        jz @skip  {skip if we don't}
        	
        mov al, [es:di] { ok load the byte with pixels we might need to keep }
        mov ah, [ds:si] { load the image buffer tail end }
        and al, dl { mask off the pixels we're keeping}
        or al, ah  { add pixels from buffer }
        mov [es:di], al { write pixel back to screen }    

     @skip:
        {update ofsets}
        sub si, width
        add si, bwidth
        add di, 80
        sub di, width
        
        loop @firstbank
        
        { ok first bank has been copied, copy the second bank.}
        
        {reset only the screen ofset, the buffer should be in the right place.}
        {load the screen ofset}
        mov ax, tofs
        mov di, ax
        xor di, $2000 {switch screen bank}
        mov ax, y {check for and add a line if we're putting on an odd line}
        and ax, $1
        jz @evenline
        add di, $50   
      @evenline:
        {ok ofsets and segments are done, load the row counter}
        mov cx, sizey
        shr cx,1
        jz @skipsecondbank
       
     @secondbank: {draw all the rows in the first bank from the buffer}
        { write first byte using mask }
        mov ah, [es:di]  {load pixels from screen}
        mov al, [ds:si]  {load image buffer pixels }
        and ah, dh	 {mask pixels we need}
        or al, ah        {or these with those from buffer}
        mov [es:di], al  {write to screen}
        
        mov bx, width
        or bx, bx        { check if width = 0 and skip further drawing }
        jz @skip2
        inc di           {increment offsets }
        inc si
        xchg bx, cx     {swap cx and bx (so as to save the row count but use cx for string copy)}
        dec cx           { already done the start byte so update counter }

        rep movsb       {copy pixel bytes from image buffer to screen if needed}
        
        xchg bx, cx     {swap them back so as to save the row counter back to cx}

        {write last byte}
        or dl, dl {test if we need a last byte}
        jz @skip2  {skip if we don't}
        	
        mov al, [es:di] { ok load the byte with pixels we might need to keep }
        mov ah, [ds:si] { load the image buffer tail end }
        and al, dl { mask off the pixels we're keeping}
        or al, ah  { add pixels from buffer }
        mov [es:di], al { write pixel back to screen }    

     @skip2:
        {update ofsets}
        sub si, width
        add si, bwidth
        add di, 80
        sub di, width
        
        loop @secondbank
     @skipsecondbank:
                        
        pop ds
     end;
end;

{puts an image to the screen, XORs it with what's already on screen.}
{ could be easily modified to do AND or NOT as well }
procedure putImageXOR(x,y : word; bitmap : pointer);
var
   bseg,bofs   : word;
   tseg,tofs   : word;
   sizex,sizey : word;
   bwidth      : word; { width of the buffer }
   width       : word; { width of section to copy }
begin
     if checkBounds(x,y) then exit;
     bseg := seg(bitmap^);
     bofs := ofs(bitmap^);
     tseg := targseg;
     tofs := screenOfset(x,y);

     sizex := memw[bseg:bofs];
     sizey := memw[bseg:bofs+2];
   {implement this in assembly - slightly faster because pascal does multiple shifts slowly
     and I can save some compute keeping values in registers.
     bwidth := (sizex shr 2) + 2;
     {adjust the ofset of the buffer to the already shifted copy
     bofs := bofs + 4 + ((x and $3) * bwidth * sizey);
     if (x+sizex>319) then
        sizex := 320-x;
     if (y+sizey>199) then
        sizey := 200-y;
     width := ((sizex + (x and $3)) shr 2) + 1; in bytes that are to be copied and xor'ed
     if ((x shr 2) + width > 80) then width:= 80 - ( x shr 2);
 }
     asm
        mov ax, sizex
        shr ax,1
        shr ax,1
        add ax,2
        mov bwidth,ax

        mov ax, x
        and ax, $3
        mov bx, ax {save a copy to use later}
        mul bwidth
        mul sizey
        add ax,4
        add ax,bofs
        mov bofs,ax

        mov ax,x
        add ax,sizex
        cmp ax,$013F
        jbe @sizexOk
        mov ax,$140
        sub ax,x
        mov sizex,ax
   @sizexOk:

        mov ax,y
        add ax,sizey
        cmp ax,$C7
        jbe @sizeyOk
        mov ax, $C8
        sub ax, y
        mov sizey,ax
   @sizeyOk:
   
        mov ax, bx {use the copy of x and $3 from earlier}
        add ax, sizex
        shr ax,1
        shr ax,1
        inc ax
        mov width, ax
        mov bx, x
        shr bx,1
        shr bx,1
        add ax, bx
        cmp ax, $50
        jbe @widthOk
        mov ax, $50
        sub ax, bx
        mov width, ax
     @widthOk:
     end;
     { AX will be for working - loading pixel bytes and manipulating them
       BX 
       CX byte counter 
       DX row counter 
       DS:SI pointer to image buffer (source)
       ES:DI pointer to screen/backbuffer (destination }
     asm
        push ds
        {load segment registers (both)}
        mov ax, bseg
        mov ds, ax
        mov ax, tseg
        mov es, ax
        {load ofset for image buffer}
        mov ax, bofs
        mov si, ax
        {load the screen ofset}
        mov ax, tofs
        mov di, ax
        {ok ofsets and segments are done, load the row counter and shift count}
        mov dx, sizey
        shr dx, 1
        jnc @evenCount
        inc dx
     @evenCount:

        {copy first bank}       
     @firstbank: {start of drawing a row }
        mov cx, width    { load cx with the byte counter }
     @byte:
        { write byte using xor }
        mov al, [ds:si]  {load image buffer pixels }
        xor [es:di], al  {write to screen}
        inc di           {increment offsets here in case width=0}
        inc si
        loop @byte

        {update ofsets}
        sub si, width
        add si, bwidth
        add di, 80
        sub di, width
        
        dec dx {done drawing the row pop so we can count rows}
        jnz @firstbank
        
        {load the screen ofset}
        mov ax, tofs
        mov di, ax
        xor di, $2000 {switch the bank we're drawing to}
        mov ax, y {check for and add a line if we're putting on an odd line}
        and ax, $1
        jz @evenline
        add di, $50   
      @evenline:
        {ok ofsets and segments are done, load the row counter and shift count}
        mov dx, sizey
        shr dx, 1
        jz @skipsecondbank

        {copy second bank}       
     @secondbank: {start of drawing a row }
        mov cx, width    { load cx with the byte counter }
     @byte2:
        { write byte using xor }
        mov al, [ds:si]  {load image buffer pixels }
        xor [es:di], al  {write to screen}
        inc di           {increment offsets here in case width=0}
        inc si
        loop @byte2

        {update ofsets}
        sub si, width
        add si, bwidth
        add di, 80
        sub di, width
        
        dec dx {done drawing the row pop so we can count rows}
        jnz @secondbank
     @skipsecondbank:
        
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
              af:= ((a * 3) div 4) {* 320} ;
              bf:= ((b * 3) div 4) {* 320} ;
              yofs := (y * 320) {+ targofs} ;

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

function setDrawMode(m : byte):boolean;
begin
   setDrawMode := false;
   if not(inited) then exit;
   if ((mode=0) and (m>0)) then
   begin
      if maxavail<16384 then exit; {not enough memory to change to another mode!}
      setDrawMode := true;
      getmem(backbuffer, 16384);
      fillmem(seg(backbuffer^),ofs(backbuffer^),0,16384);
      mode := m;
   end;
   if ((mode>0) and (m=0)) then
   begin
      setDrawMode := true;
      freemem(backbuffer,16384);
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
   copymem(seg(backbuffer^),ofs(backbuffer^),cardseg,cardofs,16384);
end;

procedure copyToBuffer; {copy screen to back buffer}
begin
   if mode = 0 then exit;
   copymem(cardseg,cardofs,seg(backbuffer^),ofs(backbuffer^),16384);
end;

procedure copySegment(x,y,sizex,sizey : word; dir : boolean);
var
   sseg,sofs : word;
   tseg,tofs : word;
begin
   if checkBounds(x,y) then exit;
   if checkBounds(x+sizex-1,y+sizey-1) then exit;
   if mode=0 then exit;
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
      xor cx,cx {cx will hold which bank the first row is in}
      mov dx,80 {dx holds whether the next bank switch also goes down a row}
      mov ax,y  
      shr ax,1
      jnc @evenRow
      xor dx,dx
      mov cx,$2000
   @evenRow:
      push dx {dx is cleared by mul, who knew?}
      mov bx,80
      mul bx
      pop dx  {restore the value I'll need later}
      mov bx, x
      shr bx, 1
      shr bx, 1
      add cx, bx
      add cx, ax
      mov bx, cx
      {load source pointer}
      mov cx, sseg
      mov ds, cx
      mov si, bx
      add si, sofs
      {load destination pointer}
      mov cx, tseg
      mov es, cx
      mov di, bx
      add di, tofs
      {load counter with the number of rows bx with width}
      mov cx, sizey
      mov bx, sizex
      shr bx, 1 {need shrink bx as it's a count of pixels}
      shr bx, 1
      inc bx
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
      xor dl,80
      add si,dx
      sub si,bx
      xor si, $2000
      add di,dx
      sub di,bx
      xor di, $2000
      loop @row
      

      pop ds
   end;
end;

begin
   inited := false;
   targseg := cardseg;
   targofs := cardofs;
   exitSave := exitproc;
   exitproc := @newexitproc;
   mode:=0;
end.
