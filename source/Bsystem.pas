{common functions for bobsfury A Danson 2004}
{added 286 detection code (to decide how fast the machine is)}

unit bsystem;

interface

var
   is286 : boolean;

function checkfile(filename:string):boolean;

implementation
uses dos;

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

begin
   is286:=false;
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
