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
  1 - Hercules - not implemented
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

   {Hercules would fit here but not implemented yet.}


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
begin
   canWriteTo:= true;
   assign(f, filename);
   append(f); { don't want to change the data unless necessary - maybe we only want to check }
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
