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

{CGA only function for setting palette }
{ $1  is intensity 
  $2  is the palette 
  pal is the palette
  backg is the background colour}
procedure CGAPalette(pal, backg: byte );


{basic drawing stuff - lines and boxes}
procedure line(x,y,x1,y1 : integer; c : byte);
procedure filledBox(x,y,x1,y1: integer; c : byte);
procedure putPixel(x,y : integer; c : byte);

procedure circle(x,y,radius: word; colour: byte);

{basic blitting stuff - get and put in gwbasic terms}
{this will tell you how much memory to allocate to a
 pointer for a given screen area}
function imageSize(sx,sy:integer):integer;
procedure getImage(x,y,x1,y1 : integer; bitmap : pointer);
procedure putImage(x,y : integer; bitmap : pointer);
procedure putImageXOR(x,y : integer; bitmap : pointer);

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


{basic start-up and shutdown}
procedure init;
begin
     if (inited) then exit;
     asm
         mov ax, $0004
        int $10
     end;
     fillmem(cardseg,cardofs,0,16384);
     targseg := cardseg;
     targofs := cardofs;
     inited := true;
     mode := 0;
     exitSave := exitproc;
     exitproc := @shutdown;
end;

{$f+}
{shutdown procedure - return to text mode}
procedure shutdown;
begin
     if not(setDrawMode(0)) then exit;
     if not(inited) then exit;
     asm  {back into text mode}
        mov ax, $0003
        int $10
     end;
     inited := false;
     exitproc := exitsave;
end;
{$f-}

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

{line drawing routine, using bresenhams line algorithm}
procedure line(x,y,x1,y1: integer; c: byte);
var
   cx,cy,count,xs,ys,xm,ym:integer;
begin
    if checkBounds(x,y) then exit;
    if checkBounds(x1,y1) then exit;
    cx := x; cy := y;
    xs := x1 - x; ys := y1-y;

    xm:= sign(xs); ym := sign(ys);
    xs := abs(xs); ys := abs(ys);

    putpixel(x,y,c);

    if xs > ys then
    begin
        count := -(xs div 2);
        while (cx <> x1) do
        begin
            count := count + ys;
            cx:= cx + xm;
            if count>0 then
            begin
                 cy:=cy+ym;
                 count := count - xs;
            end;
            putpixel(cx,cy,c);
            {mem[targseg:targofs + cx + cy] := c;}
        end;
    end
    else
    begin
         count := -(ys div 2);
         {y1 := y1 * 320;}
         while (cy <> y1) do
         begin
             count := count + xs;
             cy := cy + ym;
             if count>0 then
             begin
                  cx:=cx + xm;
                  count := count - ys;
             end;
             {mem[targseg: targofs + cx + cy] := c;}
             putpixel(cx,cy,c);
         end;
    end;
end;

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

{filled box routine}
procedure filledBox(x,y,x1,y1: integer; c : byte);
var
   rowByte : byte; {byte that would draw all 4 pixels }
   maskS, maskE : byte; { mask for the start and end of the row }
   rowLength : word; {bytes to direct copy between start and end}
   
begin
   if checkBounds(x,y) then exit;
   if checkBounds(x1,y1) then exit;
   if (x>x1) then
      swapI(x,x1);
   if (y>y1) then
      swapI(y,y1);
   rowByte := fillbyte(c);
   maskS := startMask[x and $3];
   maskE := endMask[x1 and $3];
   rowLength := (x1 shr 2) - (x shr 2) - 1;
   asm
       mov cl, 80 
       {CL will store the value which will determine if 
       the offset is incremented for the next row (will be moved later)}
       {load segment}
       mov bx, targseg
       mov es,bx
       {calulate ofset}
       xor di,di
       mov ax,y
       shr ax,1
       jnc @even
       xor cl, cl
       mov di, $2000
   @even:
       mov bx,x
       shr bx,1
       shr bx,1
       mov dx, 80
       mul dx
       add di, bx
       add di, ax
       add di, targofs
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
procedure putPixel(x,y : integer; c : byte);
begin
    if checkBounds(x,y) then exit;
    asm {assembly implementation}
       {load segment}
       mov bx, targseg
       mov es,bx
       {calulate ofset}
       xor di,di
       mov ax,y
       shr ax,1
       jnc @even
       mov di, $2000
   @even:
       mov bx,x
       shr bx,1
       shr bx,1
       mov dx, 80
       mul dx
       add di, bx
       add di, ax
       add di, targofs
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
function imageSize(sx,sy:integer):integer;
begin
     imageSize := ((sx div 4) + 2  ) * 4 * sy + 4;
end;

{gets an image and stores it in a chunk of memory, be sure to allocate enough memory}
procedure getImage(x,y,x1,y1 : integer; bitmap : pointer);
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
   sizex := abs(x-x1) + 1;
   sizey := abs(y-y1) + 1;
   fillmem(bseg, bofs, 0, imageSize(sizex, sizey));
   rowSize := (sizex div 4) + 1;
   buffwidth := rowSize + 1;
   memw[bseg:bofs] := sizex;
   memw[bseg:bofs+2] := sizey;
   bofs := bofs + 4; {set to begining of buffer}
   if y>y1 then y:=y1;
   if x>x1 then x:=x1;
   shift := (x mod 4) * 2;
   {figure out the starting address from the source}
   sseg := targseg;
   sofs := (x div 4) + (80 * (y shr 1)) + targofs;
   if y and 1 = 1 then sofs := sofs or $2000; {set the correct bank}
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
procedure putImage(x,y : integer; bitmap : pointer);
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
     tofs := (x div 4) + (80 * (y shr 1)) + targofs;
     if y and 1 = 1 then tofs := tofs or $2000; {set the correct bank}
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
procedure putImageXOR(x,y : integer; bitmap : pointer);
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
     tofs := (x div 4) + (80 * (y shr 1)) + targofs;
     if y and 1 = 1 then tofs := tofs or $2000; {set the correct bank}     sizex := memw[bseg:bofs];
     sizey := memw[bseg:bofs+2];
     bwidth := (sizex shr 2) + 2;
     {adjust the ofset of the buffer to the already shifted copy}
     bofs := bofs + 4 + ((x and $3) * bwidth * sizey);
     if (x+sizex>319) then
        sizex := 320-x;
     if (y+sizey>199) then
        sizey := 200-y;
     width := ((sizex + (x and $3)) shr 2) + 1; {in bytes that are to be copied and xor'ed}
     if ((x shr 2) + width > 80) then width:= 80 - ( x shr 2);
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
end.
