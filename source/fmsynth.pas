{Lowest level access to the adlib/sound blaster sound card}
{A Danson 2003}

unit fmsynth;

interface

  const
     adlib = $388;
     sbproleft = $220;
     sbproright = $222;

     bits : array[0..7] of byte = ($01,$02,$04,$08,$10,$20,$40,$80);
     op1 :array[1..9] of byte = ($00,$01,$02,$08,$09,$0A,$10,$11,$12);
     op2 :array[1..9] of byte = ($03,$04,$05,$0B,$0C,$0D,$13,$14,$15);

function detect(aport:word):boolean;
procedure writetosb(aport:word;rg,data:byte);
function readstatus(aport:word):byte;
procedure setwaveformcontrol(aport:word;t:boolean);
procedure reset(aport :word);

implementation

{special delay induced by reading status port}
Procedure Delay(ms,aport: word);
var i:word;
    z:byte;
begin
   for i:=1 to ms do
      z:=port[aport];
end;

procedure writetoLPT(port :word; rg, data :byte);
var
   lptbase,lptctl : word;
begin
   lptbase := memw[$0000:$0408 + pred(port)*2];
   lptctl := lptbase + 2;

   {port[lptbase]:= rg;
   port[lptctl]:=13;
   port[lptctl]:=9;
   port[lptctl]:=13;}
   asm
      mov dx,lptbase
      mov al,rg
      out dx,al
      mov dx,lptctl
      mov al,13
      out dx,al
      mov al,9
      out dx,al
      mov al,13
      out dx,al
   end;

   delay(6,lptctl);

{   port[lptbase] := data;
   port[lptctl]:=12;
   port[lptctl]:=8;
   port[lptctl]:=12;}
   asm
      mov dx,lptbase
      mov al,data
      out dx,al
      mov dx,lptctl
      mov al,12
      out dx,al
      mov al,8
      out dx,al
      mov al,12
      out dx,al
   end;

   delay(35,lptctl);
end;

procedure writetosb(aport:word;rg,data:byte);
begin
   if (aport<10) then
   begin
      writetoLPT(aport,rg,data);
      exit;
   end;
   port[aport]:=rg;
   delay(6,aport);
   port[aport+1]:=data;
   delay(35,aport);
end;

function readstatus(aport:word):byte;
begin
   readstatus:=port[aport];
end;

procedure setwaveformcontrol(aport:word;t:boolean);
var data:byte;
begin
   data:=$00;
   if t then data:=bits[5];
   writetosb(aport,$01,data);
end;

procedure reset(aport : word);
var i : byte;
    d : byte;
begin
   for i:=1 to 255 do
   begin
      writetosb(aport,i,$00);
   end;
end;

function detect(aport :word) :boolean;
var stat,stat2 : byte;
begin
   detect:=false;
   if aport<10 then {if outputting to OPL2LPT then don't attempt detection}
   begin
      detect:=true;
      exit;
   end;
   writetosb(aport,$04,$60);
   writetosb(aport,$04,$80);
   stat:=readstatus(aport);
   writetosb(aport,$02,$FF);
   writetosb(aport,$04,$21);
   delay(83,aport);
   stat2:=readstatus(aport);
   writetosb(aport,$04,$60);
   writetosb(aport,$04,$80);
   if ( ((stat AND $E0) =$00 ) and ((stat2 And $E0) = $C0) ) then detect:=true;
end;


end.
