{common functions for bobsfury A Danson 2004}
{added 286 detection code (to decide how fast the machine is)}

unit bsystem;

interface

var
   is286  : boolean;
   EGAmem : byte; {ega memory 0 = 64k 1 = 128k etc..}

{checks if a file exists}
function checkfile(filename:string):boolean;

{ checks if a file is writable }
function canWriteTo(filename : string):boolean;

{ detect highest level graphics card
  0 - none
  1 - Hercules 
  2 - CGA
  3 - EGA
  4 - VGA
  5 - VESA }
function detectGraphics:byte;


implementation
uses dos;

type
   kbuffer = array[0..1023] of char; 
   bufptr  = ^kbuffer;

function detectGraphics:byte;
var
   regs		      : Registers;
   buffer	      : bufptr;
   oldvalue, newvalue : byte;
   i		      : word;
begin
   new(buffer);
   {test for a VESA card}
   regs.es := seg(buffer^);
   regs.di := ofs(buffer^);
   regs.ax := $4F00;
   intr($10, regs);

   if (regs.ax = $004F) then {check that it succeeded and the signature is in the buffer}
      if (buffer^[0] = 'V') and (buffer^[1]='E') and (buffer^[2]='S') and (buffer^[3]='A') then
      begin
	 detectGraphics := 5; { VESA BIOS detected!}
	 dispose(buffer);
	 exit;
      end;
   dispose(buffer);

   {Check for a VGA card}
   regs.ax := $1A00;
   intr($10,regs);

   if ( regs.al = $1A) then {VGA BIOS call supported, is it a VGA}
      if (regs.bl=$7) or (regs.bl =$8) then
      begin
	 detectGraphics := 4;
	 exit;	 
      end;

   {check for a EGA card}
   regs.ax := $1200;
   regs.bl := $10;
   intr($10,regs);

   { test is EGA is present based on result }
   if not(regs.bl = $10) then
   begin
      {EGA memory size is (bl + 1) * 64k }
      EGAmem := regs.bl;
      detectGraphics := 3;
      exit;
   end;

   {check for a CGA card}
   port[$3d4] := $0F;
   oldvalue := port[$3d5];
   port[$3d5] := $4F;
   {delay for a short while (by looping)}
   for i := 0 to 1000 do
      newvalue := 0; {just something to do for the loop}
   newvalue := port[$3d5];
   port[$3d5] := oldvalue;
   if newvalue = $4F then
   begin
      detectGraphics := 2;
      exit;
   end;

   {Hercules }

   {first check that there is a CRTC chip (there for MDA and HERC}
   {similar process for CGA just on a different port.}
   port[$3B4] := $0F; { set the register index to the cursor l register }
   oldvalue := port[$3B5]; {save the value}
   port[$3b5] := $4F; {set a value}
   {delay for a bit}
   for i:= 1 to 1000 do
      newvalue := 0;
   newvalue := port[$3B5];
   port[$3B5] := oldvalue;
   if newvalue = $4F then
   begin {there is a 6845 present in the right place - test if hercules}
      { Try and detect the VSYNC bit toggle on the status register.
      MDA does not toggle it.}
      newvalue := port[$3BA] and $80;
      oldvalue := newvalue;
      for i:= 1 to $8000 do
      begin
	 newvalue := port[$3BA] and $80;
	 if (newvalue <> oldvalue) then
	 begin {the bit has toggled we can confirm hercules}
	    detectGraphics := 1;
	    exit;
	 end;
	 oldvalue := newvalue;
      end;
   end;

   {if nothing detected return 0}
   detectGraphics := 0;
end;



function checkfile(filename:string):boolean;
var s:pathstr;
begin
     checkfile:=true;
     s:=fsearch(filename,'');
     if s='' then
        begin
         checkfile:=false;
        end;
end;

{$I-}
function canWriteTo(filename : string):boolean;
var
   f	  : text;
   result : word;
   exists : boolean;
begin
   canWriteTo:= true;
   exists := checkfile(filename);
   assign(f, filename);
   if exists then
      append(f) { don't want to change the data unless necessary - maybe we only want to check }
   else
      rewrite(f);
   result := IOResult;
   if (result <> 0) then
      canWriteTo := false
   else
      close(f);
end;
{$I+}

begin
   is286:=false;
   EGAmem := 0;
   asm
     pushf
     pop bx
     and bx, $0FFF
     push bx
     popf
     pushf
     pop bx
     and bx, $F000
     cmp bx, $F000
     mov is286,0
     jz @@1
     mov is286,1
   @@1:
   end;
end.
