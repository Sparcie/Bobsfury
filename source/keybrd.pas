{ Keyboard hardware interface unit - A Danson 2011 }
{  I really should have learned to do this sooner ... it was pretty easy :P}

unit keybrd;

interface

var
   scancode : array[1..20] of byte;

function keyFace(sc : byte):string; {returns the name of the keyface matching the scan code}
function lastKeyPressed:byte;      {returns the scancode of the last keypress}

function pressed(k : byte):boolean; {determines if a key in our scancode list is pressed }
procedure clearKey(k : byte);       {set the state of a key in the scancode list to not pressed }

{replacements for CRT functions}
function keypressed:boolean; { returns true if there are keys waiting in the BIOS key buffer }
function readkey:char;       { returns a character from the BIOS key buffer }


{$I defines.pas }

implementation

uses dos;

var
   oldint09    : pointer;
   exitsave    : pointer;
   extended    : boolean;
   lastPressed : byte;
   keys	       : array[0..255] of boolean; {normal keys 0- 127 extended keys 128 - 255 }
   head	       : integer absolute $0040:$001A; 
   tail	       : integer absolute $0040:$001C;
   kbdbuff     : array[30..62] of byte absolute $0040:$001E;
   bscancode   : byte; {BIOS scan code saved when the ascii value is 0}

const
   key_faces: array[1..88] of string[12] =
   ('ESCAPE','1','2','3','4','5','6','7','8','9','0',
    '-','=','BACKSPACE','TAB','Q','W','E','R','T','Y','U','I','O','P',
    '[',']','ENTER','LEFT CTRL','A','S','D','F','G','H','J','K','L',';','"',
    '`','LEFT SHIFT','Unknown','Z','X','C','V','B','N','M',',','.','/','RIGHT SHIFT',
    'KEYPAD *','LEFT ALT','SPACE','CAPSLOCK','F1','F2','F3','F4','F5','F6',
    'F7','F8','F9','F10','NUMLOCK','SCROLL LOCK','KEYPAD 7','KEYPAD 8',
    'KEYPAD 9','KEYPAD -','KEYPAD 4','KEYPAD 5','KEYPAD 6','KEYPAD +',
    'KEYPAD 1','KEYPAD 2','KEYPAD 3','KEYPAD 0','KEYPAD .','Unknown','Unknown'
    ,'Unknown','F11','F12');
   {extended keys
   28   ENTER        (KEYPAD)              75   LEFT         (NOT KEYPAD)
   29   RIGHT CONTROL                      77   RIGHT        (NOT KEYPAD)
   42   PRINT SCREEN (SEE TEXT)            79   END          (NOT KEYPAD)
   53   /            (KEYPAD)              80   DOWN         (NOT KEYPAD)
   55   PRINT SCREEN (SEE TEXT)            81   PAGE DOWN    (NOT KEYPAD)
   56   RIGHT ALT                          82   INSERT       (NOT KEYPAD)
   71   HOME         (NOT KEYPAD)          83   DELETE       (NOT KEYPAD)
   72   UP           (NOT KEYPAD)         111   MACRO
   73   PAGE UP      (NOT KEYPAD)
   }

{replacements for CRT functions - from disassembly to behave the same}
function keypressed:boolean; assembler; { returns true if there are keys waiting in the BIOS key buffer }
asm
   cmp bscancode, 0 {check if there was a non-ascii key}
   jne @key         {return true if there was}
   mov ah,01
   int $16
   mov al, 00
   je @nokey
@key:  
   mov al, 01     
@nokey:
end;

function readkey:char; assembler;       { returns a character from the BIOS key buffer }
asm
   mov al, bscancode {check if we need to return the value stored (if there was a non-ascii key)}
   mov bscancode, 0  {clear the non-ascii stored key}
   or al, al
   jne @done         {jump to end to return the non-ascii key if there was one}
   xor ah,ah      
   int $16          {call keyboard interupt, al will contain the ascii character}  
   or al, al        {check if there is an ascii code}
   jne @done        {return the ascii code if there was one (jump to the end)}
   mov bscancode, ah {save the scancode to be returned next call if the ascii code was $0 }
   or ah,ah          {check if the scancode was 0}
   jne @done
   mov al, 03        {set the output to something else if the scancode was 0}
@done:
end;

function lastKeyPressed:byte;
{returns the last scancode}
begin
   lastKeyPressed:=lastPressed;
end; { lastKeyPressed }

function pressed(k : byte):boolean;
begin
   pressed := keys[scancode[k]];
end;

procedure clearKey(k : byte);
begin
   keys[scancode[k]] := false;
end;

function keyFace(sc : byte):string;
{returns the keyface of a pressed scancode}
begin
   if (sc and $80) = 0 then
   begin
      if ((sc>0) and (sc<89)) then	 
	 keyface:= key_faces[sc]
      else
	 keyface:='Unknown';
   end
   else
   begin
      sc := sc and $7f;
      case sc of
	28  : keyface:='KEYPAD ENTER';
	29  : keyface:='RIGHT CONTROL';
	42  : keyface:='PRINT SCREEN';
	53  : keyface:='KEYPAD /';
	55  : keyface:='PRINT SCREEN';
	56  : keyface:='RIGHT ALT';
	71  : keyface:='HOME';
	72  : keyface:='UP';
	73  : keyface:='PAGE UP';
	75  : keyface:='LEFT';
	77  : keyface:='RIGHT';
	79  : keyface:='END';
	80  : keyface:='DOWN';
	81  : keyface:='PAGE DOWN';
	82  : keyface:='INSERT';
	83  : keyface:='DELETE';
	111 : keyface:='MACRO';
      else
	 keyface:='Unknown';
      end;	 
   end;
end; { keyFace }

{$ifdef XTKbd}

{$I scancode.pas}

procedure translate(code : byte);
var
   shift    : boolean;
   ascii    : byte;
   temptail : word;
begin
   {do a relatively simple translation from scan code to ascii}
   { doesn't handle capslock or numlock (maybe could do that?)}
   shift := keys[$2A] or keys[$36];
   if not(shift) then
      ascii := scantable[code]
   else
      ascii := shiftscantable[code];

   {stuff the combined code and ascii into the BIOS buffer}
   {determine a new tail value}
   temptail := tail + 2;

   {check if the buffer is full we drop the key press}
   if temptail = head then exit;

   {write to the buffer}
   kbdbuff[tail] := ascii;
   kbdbuff[tail+1] := code;
   tail := temptail;
   if tail > 60 then tail:=30;   
end;
			 
{$endif}

procedure keyhandler; interrupt;
{interrupt for processing the keys}
var
   key_in   : byte;
   scode    : byte;
   tempHead : integer;
   count    : integer;
begin
   asm cli end;
   key_in:= port[$60]; {grab the current scan code}
   {$ifndef XTKbd}
   {keyboard routine for AT keyboards/BIOS
   we can read from the keyboard, do a little processing,
   then hand control to the BIOS to handle the rest. }
   Inline(                  {call old BIOS handler }
          $9C/                   {pushf}
	  $FF/$1E/>OLDINT09);    {call far [>OldInt09]}
   scode := key_in and $7f;
   if extended then
   begin
      scode := scode or 128;
      keys[scode] := key_in < 128;
      lastpressed := scode;
      extended:=false;
   end
   else
   begin
      if not(key_in=$E0) then
      begin
	 keys[scode] := key_in < 128;
	 lastpressed := scode ;
      end
      else
	 extended:=true;
   end;
   {$else}
   {keyboard routine for XT keyboards/machines
   We have to do all the handling ourselves as reading
   from the keyboard port more than once can occasionally (not all the time)
   cause us to miss a key up/down event, causing the game to think a key is stuck}
   {reset PPI and send EOI}
   scode := port[$61];
   port[$61] := scode or $80;
   port[$61] := scode and $7F;
   {store state based on key input}
   
   scode := key_in and $7f;
   
   keys[scode] := key_in < 128;
   lastpressed := scode;
   {if it is a key down event we will translate the scan code and stuff it in the BIOS buffer}
   if (key_in < $80) then translate(scode); 
   port[$20] := $20;   
   {$endif}
   
   {this part is common for both types of machine}
   {only allow a couple of keypresses to be stored to prevent buffer overflow}
   asm cli end;
   tempHead := head;
   count := tail - head;
   if count<0 then count := (62-head) + (tail-30);
   if (count > 6) then
   begin
      head := head + 2;
      if head>60 then head:=30;
      if (head=tail) then head:=tempHead;
   end;
   asm sti end;
end;

{$F+}
procedure newExitProc;
{procedure for when the program halts - removes the interrupt}
begin
   setIntVec($09,oldint09);
   exitproc:=exitsave;
end; { newExitProc }
{$F-}

begin
   exitsave:=exitproc;
   exitproc:=@newExitProc;
   getIntVec($09,oldint09);
   setIntVec($09,@keyhandler);
   extended:=false;
   for lastPressed:=0 to 255 do
      keys[lastPressed]:=false;
   lastpressed:=0;
   bscancode := 0;
end.
