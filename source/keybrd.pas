{ Keyboard hardware interface unit - A Danson 2011 }
{  I really should have learned to do this sooner ... it was pretty easy :P}

unit keybrd;

interface

var
   scancode : array[1..20] of byte;

function keyFace(sc : byte):string; {returns the name of the keyface matching the scan code}
function lastKeyPressed:byte;      {returns the scancode of the last keypress}

function pressed(k : byte):boolean;
procedure clearKey(k : byte);

procedure clearBIOSKeyBuffer;


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

procedure clearBIOSKeyBuffer;
begin
   asm cli end;
   head := tail;
   asm sti end;
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

procedure keyhandler; interrupt;
{interrupt for processing the keys}
var
   key_in : byte;
   scode  : byte;
begin
   key_in:= port[$60]; {grab the current scan code}
   scode := key_in and $7f;
   if extended then
   begin
      keys[scode + 128] := key_in < 128;
      lastpressed := scode + 128;
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
  
   Inline(                  {call old BIOS handler }
	  $9C/                   {pushf}
	  $FF/$1E/>OLDINT09);    {call far [>OldInt09]}
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
end.
