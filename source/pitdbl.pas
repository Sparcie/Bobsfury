{ unit that will double the speed of the PIT so that INT 1C occurs more often }
{ will maintain system timing (INT 08) correctly }
{ can be adjusted to a different frequency. }
{A Danson 2017}

unit PITDBL;

interface

procedure enablePitDbl(r :byte) ; {r is the ratio, 2 is twice as fast)}
procedure disablePitDbl;
function pitRatio:integer;
function timerTick:word;

implementation
uses dos;

var
   exitsave : pointer;
   oldint08 : pointer;
   tick	    : word;
   ratio    : byte;

const
   baseClock = 18.2;

function pitRatio:integer;
begin
   pitRatio:=ratio;
end;

function timerTick:word;
begin
   timerTick:=tick;
end;

procedure int08; interrupt;
begin
   inc(tick);
   if (tick mod ratio) =0 then
   begin
      inline($9C/$FF/$1E/>oldint08); {call old handler}
   end
   else
   begin
      asm
         int $1C;
      end;
      port[$20] := $20; {acknowledge interrupt - old handler will do this as well, so only acknowledge if it didn't run.}
   end;
end;

procedure setPITSpeed(sp : word);
begin
   port[$43] := $36;
   port[$40] := lo(sp);
   port[$40] := hi(sp);
end;


{$F+}
procedure newexitproc;
begin
   exitproc := exitsave;
   setintvec($08,oldint08);
   setPITSpeed($FFFF);
end;

{$F-}


procedure enablePitDbl(r :byte) ;
var
   sp : word;
begin
   sp := $FFFF div r;
   setPITspeed(sp);
   ratio:=r;
end;

procedure disablePitDbl;
begin
   setPITSpeed($FFFF);
   ratio:=1;
end;


begin
   tick:=0;
   ratio:=1;

   getintvec($08,oldint08);
   setintvec($08,@int08);

   exitsave:= exitproc;
   exitproc := @newexitproc;

end.
