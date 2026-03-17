{ 
  Hercules Graphics unit made for Bob's fury as part of a replacement for
  the BGI. Same interface as the VGA unit so it's easy to use them
  interchangably.
  
  A Danson 2026
 }

unit Hercules;

interface

const
     { patterns to use instead of colours for lines  - from least to most}
     linePatterns : array[0..4] of byte = ( $00, $88, $CC, $EE, $FF );
     { fill patterns to use with filled box - from least to most }
     fillPatterns : array[ 0..4  , 0..3] of byte = (
                    ($00, $00, $00, $00), { black fill }
                    ($88, $22, $88, $22), { 25 % fill }
                    ($AA, $55, $AA, $55), { 50% fill }
                    ($77, $DD, $77, $DD), { 75% fill }
                    ($FF, $FF, $FF, $FF)  { 100% fill }                    
                    );

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

implementation

uses fixed,gcommon;

const
   {bitmask for selecting a single pixel}
   pixel     : array[0..7] of byte = ($80, $40, $20, $10, $08, $04, $02, $01);
   {bitbask for selecting a range of leading horizontal pixels}
   leadmask  :array[0..7] of byte = ($FF, $7f, $3F, $1F, $0F, $07, $03, $01); 
   {bitmask for selecting a range of trailing horizontal pixels}
   trailmask :array[0..7] of byte = ($80, $C0, $E0, $F0, $F8, $FC, $FE, $FF); 

var
   cardseg         : word; { can be one of two pages either $B000 or $B800 }
   inited	   : boolean; {have we started the display?}
   exitSave	   : pointer;

{check if co-ordinates are on screen in vesa mode}
function checkHBounds(x,y:word):boolean; assembler; {returns true on failure!}
asm
    mov ax, 0
    mov bx, x
    mov cx, y
    cmp bx, 639
    ja @failed
    cmp cx, 351
    ja @failed
    jmp @done
@failed:
    mov al, 1
@done:
end;

{basic start-up and shutdown}
procedure init;
const
     hregs : array[0..13] of byte =
             ($35, $28, $2D, $07, $5B, $02, $57, $57, $02, $03, $00, $00, $00, $00);
var reg : word;
begin
     if (inited) then exit;
        port[$3B8] := $02; {disable video output - turn on graphics }
        port[$3BF] := $03; {unlock graphics mode and page 1 }

        for reg := 0 to 13 do
        begin
            port[$3B4] := reg;
            port[$3B5] := hregs[reg];
        end;
        port[$3B8] := $0A; { enable video output in graphics mode }
     inited := true;
     cardseg := $B000;
     cls;
end;

procedure cls;
begin
   fillmem(cardseg, 0, 0, $1B80);
      fillmem(cardseg, $2000, 0, $1B80);
   fillmem(cardseg, $4000, 0, $1B80);
   fillmem(cardseg, $6000, 0, $1B80);
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
const
     hregs : array[0..13] of byte =
             ($61, $50, $52, $0F, $19, $06, $19, $19, $02, $0D, $0B, $0C, $00, $00);
var reg : word;
begin
   if not(inited) then exit;
   cls;
   port[$3B8] := $00; {disable video output - turn off graphics }
   port[$3BF] := $00; {lock graphics mode and page 1 }
   
   for reg := 0 to 13 do
   begin
      port[$3B4] := reg;
      port[$3B5] := hregs[reg];
   end;
   {clear screen - need to output the right attribute and character 80x25 times }
   for reg := 0 to 1999 do
      MemW[$B000 : reg shl 1] := $0720;
   {reset cursor location }
   port[$3B4] := 14;
   port[$3B5] := 0;
   port[$3B4] := 15;
   port[$3B5] := 0; 
   port[$3B8] := $08; { enable video output in text mode }
   inited := false;
end;

function screenOffset(x,y : word):word; Assembler;
asm
    {to calculate the screen offset we need
     The bank = (y and 3) * $2000
     horizontal offset = (x shr 3)
     vertical offset = (y shr 2) * 80 (for 640 resolution)
     We need all these things added together }
    {lets do the bank first }
    mov ax, y { get y component }
    and ax, 3 { mask off the bank}
    mov cl, 13 { set up the shift count }
    shl ax, cl { shift the bank number by 13 bits equiv to  * by $2000 }
    {do the horizontal - use BX }
    mov bx, x
    shr bx, 1 { 1 bit shifts are faster, only need 3 }
    shr bx, 1
    shr bx, 1
    add ax, bx {add the horizontal component}
    {ok now we need to do the vertical component}
    xor bx,bx {clear BX, we're going to accumulate the result here}
    mov cx,y  {load cx with the begining value}
    and cx,$FFFC {mask off the bank }
    shl cx,1  {we shl 2, by masking we avoid the }
    shl cx,1  { need to shr 2 then shl 4, we can just shl 2 }
    add bx, cx { save this value - we need to add to it }
    shl cx,1   { shl 2 again for the 2^6 value to add }
    shl cx,1
    add ax, cx { add both values to AX }
    add ax, bx { this is equiv of adding (y shr 2) * 80 }
    { ax is the return value }
end;

{basic drawing stuff - lines and boxes}

{line drawing routine, using bresenhams line algorithm}
{ rather than being a colour C is a line pattern (index into const array) }
procedure line(x,y,x1,y1: word; c: byte);
var
   count,xs,ys,xm,ym : integer;
   cx,cy	     : word;
   ofs		     : word;
begin
   if checkHBounds(x,y) then exit;
   if checkHBounds(x1,y1) then exit;
    
   c:= linePatterns[c mod 5];

   xs := x1 - x; ys := y1-y;

   xm:= sign(xs); ym := sign(ys) ;
   xs := abs(xs); ys := abs(ys);

   ofs := screenOffset(x,y);

   if xs >= ys then
   begin
      if xm < 0 then
      begin
	 {swap the co-ords so we draw left to right}
	 swapW(x,x1);
	 swapW(y,y1);
	 ym := sign( y1 -y );
	 ofs := screenOffset(x,y);
      end;
      asm
        { The assembly portion of line drawing
	  AH - current video memory byte we're working on
	  AL - current bit for current pixel
	  BH - a working space.
	  BL - line pixel pattern
	  CX - count for number of pixels to draw
	  DX - error variable for bresenhams
	  SI - increment value for changing rows
	ES:DI - current video memory address. }
         mov ax, cardseg {load starting address}
         mov es, ax
         mov di, ofs
         { figure out which bit to start drawing in a byte }
         mov cx,x {get the x co-ordinate}
         and cx, $7
         mov al, $80
         shr al, cl
         { load the row increment data }
         mov si, ym
         mov cl, 13
         shl si, cl
         { load the line pattern byte }
         mov bl, c
         { load the count for the number of pixels to draw }
         mov cx, x1
         sub cx, x
         add cx, 1
         { initial value of the error variable }
         xor dx,dx
         sub dx, xs
         sar dx, 1
         { load the video byte from vram and 'draw' the first pixel.}
         mov ah, [es:di]
         not al     { invert pixel mask}
         and ah, al  { mask off pixel to write }
         not al     {revert mask }
         mov bh, bl { copy line pattern }
         and bh, al { mask for pixel we need }
         or ah, bh  { add the pixel from the pattern to the video byte }

      @lineLoop: {start of the line drawing loop}
         shr al, 1  {move to next pixel}
         jnc @xsamebyte {check if it's in the same offset}
         mov [es:di], ah {write video memory out}
         inc di { next byte for next pixel }
         mov al, $80 {set mask for next pixel}
         mov ah, [es:di] {load next video byte}
      @xsamebyte:
         add dx, ys
         jl @xsamerow
         mov [es:di], ah {write video memory out}
         add di, si
         cmp di, $8000 {check if we need to fix the bank because we wrapped }
         jb @xskipbank
         { ok we've established we hit a bank boudary (either from 0-3 or 3-0)
	   We need to figure out which direction and act appropriately }
         { are we going up or down when adding si to di?}
         cmp si, 0
         jg @xbankpos
         { direction is negative }
         and di, $1FFF
         or di, $6000
         sub di, 80
         jmp @xskipbank
      @xbankpos:
         { direction is positive }
         and di, $1FFF
         add di, 80
      @xskipbank:
         mov ah, [es:di] {load next video byte}
         sub dx, xs      {last step of row adjustment - adjust error value }
      @xsamerow:
         { ok at this point we should update the video byte we have stored
	   as we have updated location values }
         not al     { invert pixel mask}
         and ah, al  { mask off pixel to write }
         not al     {revert mask }
         mov bh, bl { copy line pattern }
         and bh, al { mask for pixel we need }
         or ah, bh  { add the pixel from the pattern to the video byte }
         {loop if there are more pixels to draw}
         loop @lineloop
         mov [es:di], ah {write out video byte that we were working on now we are done.}
      end;
   end
   else
   begin
      if ym < 0 then
      begin
	 {swap the co-ords so we draw left to right}
	 swapW(x,x1);
	 swapW(y,y1);
	 xm := sign( x1 - x);
	 ofs := screenOffset(x,y);
      end;
      asm
         { Assembly portion of the vertical major line drawing
	   AH - current video byte
	   AL - current bit for current pixel
	   BH - working space
	   BL - Line pixel pattern
	   CX - count for number pixels to draw
	   DX - error variable for bresenhams
	   SI - increment value for changing columns
	 ES:DI - current video memory address }
         {load starting video address}
         mov ax, cardseg
         mov es, ax
         mov di, ofs
         {figure out the pixel bit}
         mov cx, x
         and cx, $7
         mov al, $80
         shr al, cl
         {load the pattern byte}
         mov bl,c
         {load the pixel draw count}
         mov cx, y1
         sub cx, y
         add cx, 1
         {initialise the error variable}
         xor dx,dx
         sub dx, ys
         sar dx, 1
         {load the column change value }
         mov si, xm
         { load the video byte from vram and 'draw' the first pixel.}
         mov ah, [es:di]
         not al     { invert pixel mask}
         and ah, al  { mask off pixel to write }
         not al     {revert mask }
         mov bh, bl { copy line pattern }
         and bh, al { mask for pixel we need }
         or ah, bh  { add the pixel from the pattern to the video byte }
         mov [es:di], ah {write video memory back}

      @ylineLoop:
         { rotate the pattern so that it applies vertically}
         ror bl, 1
         { increase y position by one }
         add di, $2000 { by switching to next bank}
         cmp di, $8000 { Check to see if we need to reset to bank 0 }
         jb @yskipBank
         and di, $1FFF { reset to bank 0 }
         add di, 80    { next row }
      @yskipBank:
         {now check if we stay in the same column}
         add dx, xs
         jl @ysameColumn
         { adjust error value }
         sub dx,ys
         { un-shift pattern - it shouldn't move if we change column }
         rol bl, 1
         { check which direction to go}
         cmp si, 0
         jg @ymoveRight
         { move left}
         rol al, 1
         jnc @ysameColumn
         dec di {if we are crossing a byte boundry move offset one byte }
         jmp @ysameColumn
      @ymoveRight:
         {move right}
         ror al, 1
         jnc @ysameColumn
         inc di { if we are crossing a byte boundry move offset one byte }
      @ysameColumn:
         {ok offsets and pixel masks have been adjusted - draw the pixel.}
         mov ah, [es:di]
         not al     { invert pixel mask}
         and ah, al  { mask off pixel to write }
         not al     {revert mask }
         mov bh, bl { copy line pattern }
         and bh, al { mask for pixel we need }
         or ah, bh  { add the pixel from the pattern to the video byte }
         mov [es:di], ah {write video memory back}
         { loop if there are more pixels to draw }
         loop @ylineLoop
      end;
   end;
end;

{filled box routine}
procedure filledBox(x,y,x1,y1: word; c : byte);
var
    lmask, tmask : byte;
    dx, dy       : word;
    ofs          : word;
    leng   : word;
begin
   if checkHBounds(x,y) then exit;
   if checkHBounds(x1,y1) then exit;
   if (x>x1) then
      swapW(x,x1);
   if (y>y1) then
      swapW(y,y1);
   
   lmask := leadmask[x and $7];
   tmask := trailmask[x1 and $7];
   dx := x1 - x;
   dy := (y1 - y)+1;
   ofs := screenOffset(x,y);
   c:= c mod 5; {limit c to one of the fill patterns}

   if dx>$F then
      leng := (dx shr 3) 
   else
      leng := 0;
   
   {if (dx < ((x1 and $7) + (8 - (x and $7)) then leng := 0;}
   if (dx < 7 - (x and $7)) then
   begin
        leng:=0;
        lmask := lmask and tmask;
        tmask := 0;
   end;
   
   {do the fill - in assembly
    AX - for working
    BX - offset to filled pattern (in DS)
    CX - Row counter
    DH - lead mask
    DL - trail mask
   ES:DI - pointer to display
    SI - offset to filled pattern - copy so we can figure out the range}
   asm
      cld {clear direction flag }
      {load card seg}
      mov ax, cardseg
      mov es, ax
      {load initial offset}
      mov di, ofs
      {load and set up offset to filled pattern }
      lea bx, fillPatterns
      xor ax,ax {figure out the offset into the pattern array}
      mov al, c {take c }
      shl al, 1 { multiply by 4 (four bytes per pattern) }
      shl al, 1
      add bx, ax { add to the array offset }
      mov si, bx
      { load the masks }
      mov dh, lmask
      mov dl, tmask
      { load the row counter }
      mov cx, dy
   @nextRow:
      push di {save the current offset - will use this later}
   
      {do the lead byte with the lead mask}
      mov ah, [bx] {load the pattern in AH }
      mov al, [es:di] { load the vram byte }
      and ah, dh { mask the pattern }
      not dh { invert the mask }
      and al, dh { mask the pixels }
      not dh  {restore the mask }
      or al, ah  { combine the two }
      mov [es:di], al {write back to card}
      inc di

      {check if we need to do the bulk write portion. }
      mov ax, leng
      or ax,ax
      jz @skipBulk

      {we know we need to do bulk copying - prepare}
      push cx {save for later}
      mov cx, ax { load byte counter }
      mov al, [bx] { reload pattern }

      { do the copy or words}
      rep stosb
      pop cx {restore row counter}
   @skipBulk:

      {check if we need to do a trailing byte.}
      or dl, dl
      jz @skipTrail

      {do the lead byte with the trail mask}
      mov ah, [bx] {load the pattern in AH }
      mov al, [es:di] { load the vram byte }
      and ah, dl { mask the pattern }
      not dl  { invert the mask }
      and al, dl { mask the pixels }
      not dl  {restore the mask }
      or al, ah  { combine the two }
      mov [es:di], al {write back to card}
   @skipTrail:
      { ok now we need to adjust the offsets }
      pop di { rewind to start of row }
      add di, $2000 { next bank }
      cmp di, $8000 {check if greater than $8000}
      jb @bankOnly
      { if it's greater than $8000 then we need to go back to bank 0}
      { and add 80 offset }
      and di, $1FFF { reset to bank 0 }
      add di, 80    { next row in bank 0 }
   @bankOnly:
      {now adjust bx offset for pattern array}
      inc bx {next array index}
      sub bx, si { strip it down to the index into array}
      and bx, $3 { restrict the range of the index }
      add bx, si { re-add the base offset }

      { ok now we should just need to loop }
      loop @nextRow
   
   end;
end;

{put pixel routine, not the fastest way to draw}
procedure putPixel(x,y : word; c : byte); assembler;
asm
   {check bounds}
   push x
   push y
   call checkHBounds
   or al,al
   jne @skip
   { load card segment}
   mov ax, cardseg
   mov es, ax
   { get screen offset }
   push x
   push y
   call screenOffset
   mov di, ax
   { set up mask in BH for the pixels to keep }
   mov bh, $7f
   mov cx, x
   and cx, $7
   ror bh, cl
   { set up pixel to draw (either one or zero) }
   xor bl, bl
   mov cl, c
   or cl,cl
   jz @zeroPixel
   mov bl, bh 
   not bl
@zeroPixel: {draw the pixel }
   mov al, [es:di]
   and al, bh
   or al, bl
   mov [es:di], al
@skip:
end;

{basic blitting stuff - get and put in gwbasic terms}
{this will tell you how much memory to allocate to a
 pointer for a given screen area}
function imageSize(sx,sy:word):word;
begin
     imageSize := ((sx shr 3)  + 2  ) * 8 * sy + 6;
end;

{gets an image and stores it in a chunk of memory, be sure to allocate enough memory}
{ to make it faster to draw this code pre-computes all the potential pixel locations in a byte 
  So there will be 8 copies of each image in the memory buffer }
procedure getImage(x,y,x1,y1 : word; bitmap : pointer);
var
   bseg,bofs   : word; { current location in buffer we are writing to }
   sseg, sofs  : word; { source starting ofset }
   i,c	       : word; { counters for loops }
   sizex,sizey : word; { size of the image }
   rowSize     : word; {bytes per row (for a single plane)}
   pixels      : word; {pixel data we have read}
   shift       : byte; {how much we have to shift the data to align it}
   spix        : byte; { pixels/bits that were shifted and are needed for the next byte}
begin
   if checkHBounds(x,y) then exit;
   if checkHBounds(x1,y1) then exit;
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
   

     sofs := screenOffset(x,y);
      for c:= 1 to sizey do
      begin
	 for i := 1 to rowsize do
	    begin
	       pixels := swap(memw[cardseg: sofs]);
	       pixels := pixels shl shift;
               spix := hi(pixels);
               if i=rowsize then { if it's the last byte - mask off pixel data we don't need }
                   spix := spix and trailMask[ x1 and $7];
	       mem[bseg:bofs] := spix;
	       inc(bofs);
	       inc(sofs);	       
	    end;
         inc(bofs); { add padding byte - is needed to make all rows uniform length}
         {switch bank to get the next row (Hercules memory format is a pain!)}
         sofs := sofs + $2000 - rowsize  ; { next bank and start of the row}
         if sofs>=$8000 then
            sofs := ((sofs and $1FFF) + 80); { next row in bank 0 }
      end;
   { add the padding byte to rowsize }
   inc(rowsize);
      
   {make 7 shifted copies of the base image to make it faster to draw}
   {any bits that shouldn't contain pixel data should be 0 }
   for shift:= 1 to 7 do
   begin
       { set our source to the start of the image buffer }
       sseg := seg(bitmap^);
       sofs := ofs(bitmap^) + 4;
       for c:= y to y1 do
       begin
           spix := 0; {reset saved pixels at start of row}
           for i:= 1 to rowsize do
           begin
               pixels := mem[sseg: sofs];
               pixels := swap(pixels) shr shift;
               mem[bseg:bofs] := hi(pixels) or spix;
               spix := lo(pixels); { pixels we will need for the next byte }
               inc(sofs);
               inc(bofs);           
           end;
       end; 
   end;
end;


{puts an image to the screen, is a direct copy}
procedure putImage(x,y : word; bitmap : pointer);
var
   bseg,bofs   : word; { buffer pointer}
   tofs	       : word; { target ofset (screen starting location)}
   sizex,sizey : word; { sizes}
   bwidth      : byte; { width of the buffer in bytes}
   bheight     : word; { height of the buffer in pixels}
   rwidth      : byte; { width of section to copy }
   maskS       : byte; { mask for begining }
   maskE       : byte; { mask for trailing byte(s) }
begin
   if checkHBounds(x,y) then exit;
   bseg := seg(bitmap^);
   bofs := ofs(bitmap^);
   sizex := memw[bseg:bofs];
   sizey := memw[bseg:bofs+2];
   { buffer size calculations }
   bheight := sizey;
   bwidth := (sizex shr 3) + 2; {buffer width in bytes}   
   { buffer offset - select which copy of the image to use }
   bofs := bofs + 4 + ((x and $7) * (bwidth*bheight));
   tofs := screenOffset(x,y);

   if (y+sizey>352) then 
      sizey := 352-y;
   rwidth := (((x and $7) + sizex) shr 3); { how many bytes to write }


   maskS := leadmask[ x and $7]; 
   maskE := trailmask[(x + sizex -1) and $7];  
   
   {check for edge of screen for x}
   if (( x shr 3) +rwidth) > 80 then
   begin
       rwidth := 80 - (x shr 3);
       maskE := 0;
   end;
   if maskS < $FF then dec(rwidth); { the lead byte is masked don't include it in the bulk copy}
   { AX for working
     BL stores the lead mask
     BH stores the trail mask
     CX counter for number of rows
     DL rwidth copy - how many bytes to write per row
     DH the buffer row width (including padding)
     DS:SI pointer to image buffer (source)
     ES:DI pointer to display (output)}
     asm
        {save the data segment }
        push ds
        {load the screen offset and segment}
        mov ax, cardseg
        mov es, ax
        mov di, tofs
        {load the bitmap segment and offset}
        mov ax, bseg
        mov ds, ax
        mov si, bofs
        {load the masks into the registers}
        mov bl, maskS
        mov bh, maskE
        not bx  {invert the masks (the ones will be pixels to _not_ draw to)     
        { load the row and buffer width (the number of bytes to write)}
        mov dh, bwidth
        mov dl, rwidth
        { load the row counter }
        mov cx, sizey

        {ok start drawing the rows }
   @nextRow:
        {we're going to use the stack to save the current buffer and screen position
	this will make it easier to get the address for the next row in
	the buffer}
        push si
        push di

        {check if the leading byte needs to be masked}
        or bl, bl
        jz @skipLead

        {ok do the lead byte that needs masking.}
        mov al, [es:di] {load the byte from display ram}
        mov ah, [ds:si] {load the pixel data }
        and al, bl  {mask of pixels we want to draw to (keeping the others)}
        or al, ah   {add the pixels from the leading buffer byte}
        mov [es:di], al { write the data back to the vram }
        {increment offsets for next byte}
        inc si
        inc di

   @skipLead:
        {check if we need the bulk}
        or dl, dl
        jz @skipBulk {skip the bulk if there is none to write}
        { now we can bulk-copy the middle bytes }
        mov ax, cx {save the row counter for later }
        xor cx, cx
        mov cl, dl {load the bulk copy count }

        rep movsb { copy the bytes! }

        mov cx, ax {restore the row counter}
   @skipBulk:
        {check if we need the trail mask}
        or bh,bh
        jz @skipTrail
	
        {ok do the trail byte that needs masking.}
        mov al, [es:di] {load the byte from display ram}
        mov ah, [ds:si] {load the pixel data }
        and al, bh  {mask of pixels we want to draw to (keeping the others)}
        or al, ah   {add the pixels from the leading buffer byte}
        mov [es:di], al { write the data back to the vram }
   @skipTrail:
        {ok row done - pop the starting offsets off the stack }
        pop di
        pop si
        {now adjust the offsets for the next row}
        xor ax, ax
        mov al, dh
        add si, ax {I can't just add dh directly I had to use ax}
        {now adjust the screen offset - go to the next bank}
        add di, $2000
        {check if we need to wrap to bank 0 and next row }
        cmp di, $8000
        jb @endLoop
        and di,$1FFF {mask off the bank to switch to bank 0}
        add di, 80  {next row in the bank}
   @endloop:
        loop @nextRow
        { at this point the drawing should be done }        
        {restore the data segment }
        pop ds 
     end;   
end;

{puts an image to the screen, XORs it with what's already on screen.}
{ Xor is a special case where we can ignore the lead and trailing masks
  and basically just xor the data from the buffer onto the screen}
{ could be easily modified to do AND or NOT as well }
procedure putImageXOR(x,y : word; bitmap : pointer);
var
   bseg,bofs   : word; { buffer pointer}
   tofs	       : word; { target ofset (screen starting location)}
   sizex,sizey : word; { sizes}
   bwidth      : byte; { width of the buffer in bytes}
   bheight     : word; { height of the buffer in pixels}
   rwidth      : byte; { width of section to copy }
begin
   if checkHBounds(x,y) then exit;
   bseg := seg(bitmap^);
   bofs := ofs(bitmap^);
   sizex := memw[bseg:bofs];
   sizey := memw[bseg:bofs+2];
   { buffer size calculations }
   bheight := sizey;
   bwidth := (sizex shr 3) + 2; {buffer width in bytes}   
   { buffer offset - select which copy of the image to use }
   bofs := bofs + 4 + ((x and $7) * (bwidth*bheight));
   tofs := screenOffset(x,y);

   if (y+sizey>352) then 
      sizey := 352-y;
   rwidth := ( sizex shr 3) + 1; { how many bytes to write }

   
   {check for edge of screen for x}
   if (( x shr 3) +rwidth) > 80 then
   begin
       rwidth := 80 - (x shr 3);
   end;

   { AX for working
     BX count for the row bytes to write
     CX counter for number of rows
     DL rwidth copy - how many bytes to write per row
     DH the buffer row width (including padding)
     DS:SI pointer to image buffer (source)
     ES:DI pointer to display (output)}
     asm
        {save the data segment }
        push ds
        {load the screen offset and segment}
        mov ax, cardseg
        mov es, ax
        mov di, tofs
        {load the bitmap segment and offset}
        mov ax, bseg
        mov ds, ax
        mov si, bofs
        { load the row and buffer width (the number of bytes to write)}
        mov dh, bwidth
        mov dl, rwidth
        { load the row counter }
        mov cx, sizey

        {ok start drawing the rows }
   @nextRow:
        {we're going to use the stack to save the current buffer and screen position
	this will make it easier to get the address for the next row in
	the buffer}
        push si
        push di

        xor bx,bx
        mov bl, DL

   @xorByte:
        {take an input byte and xor it on vram}
        mov al, [es:di] {load the byte from display ram}
        mov ah, [ds:si] {load the pixel data }
        xor al, ah   {add the pixels from the leading buffer byte}
        mov [es:di], al { write the data back to the vram }
        {increment offsets for next byte}
        inc si
        inc di
        dec bl
        jnz @xorByte

        {ok row done - pop the starting offsets off the stack }
        pop di
        pop si
        {now adjust the offsets for the next row}
        xor ax, ax
        mov al, dh
        add si, ax {I can't just add dh directly I had to use ax}
        {now adjust the screen offset - go to the next bank}
        add di, $2000
        {check if we need to wrap to bank 0 and next row }
        cmp di, $8000
        jb @endLoop
        and di,$1FFF {mask off the bank to switch to bank 0}
        add di, 80  {next row in the bank}
   @endloop:
        loop @nextRow
        { at this point the drawing should be done }        
        {restore the data segment }
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
     if checkHBounds(x,y) then exit;
     clip := false;
     if (x< radius) or (y<radius) then clip :=true;
     if (639-x<radius) or (351-y<radius) then clip := true;
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
end.
