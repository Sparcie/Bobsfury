{Fixed point unit - A Danson 2015

 This unit has the basics for doing fixed point arithmetic and some
 other useful math functions such as an int version of sqrt

 fixed point numbers can be added and subtracted with normal integer
 operations. For anything else use functions from here or implement your
 own.
 }

unit fixed;

interface

function intToFixed(i : integer):integer;
function fixedToInt(i:integer):integer;
function fixedMul(i, c:integer):integer;
function fixedDiv(i, c: integer): integer;

function intSqrt(num: word):word;
function longIntSqrt(num : longint): word; 
function distance(x,y,a,b : integer):word;

{the accuracy of this isn't great}
function fixedSqrt(num: word):word;

implementation

const
     precision = 7; {the number of fractional bits}
     scale = 128; {the scaling factor}
     scsqrt = 11; { the sqrt of the scale (for fixedsqrt)}

function intToFixed(i : integer):integer;
begin
    intToFixed := i shl precision;
end;

function fixedToInt(i:integer):integer;
begin
    fixedToInt:=i shr precision;
end;

function fixedMul(i, c:integer):integer;
var
   a:longint;
begin
   a:= i;
   a:= a * c; {a now is a signed fixed point with 2 times the precision}
   fixedMul := a shr precision; {convert back to integer losing high bits unfortunately}
end;

function fixedDiv(i, c: integer): integer;
var
   a:longint;
begin
     a:= i;
     a:= a shl precision;{we shift left to avoid loss of precision }
     fixedDiv:= a div c;
end;

function intSqrt(num: word):word;
var
   xo,xn:word;
begin
     {we're using Newtons method for aproximating the sqrt}
     if (num=0) then
     begin
         intSqrt:=0;
         exit;
     end;
     xo := 0;
     xn := (num shr 1) + 1;
     while (abs(xo-xn) > 1) do
     begin
          xo := xn;
          xn := (xo + (num div xo)) shr 1;
     end;
     intSqrt := xn;
end;

function longIntSqrt(num : longint): word; 
var
   xo,xn:longint;
begin
     {we're using Newtons method for aproximating the sqrt}
     if (num=0) then
     begin
         longIntSqrt:=0;
         exit;
     end;
     xo := 0;
     xn := (num shr 1) + 1;
     while (abs(xo-xn) > 1) do
     begin
          xo := xn;
          xn := (xo + (num div xo)) shr 1;
     end;
     longIntSqrt := xn;
end;

function distance(x,y,a,b : integer):word;
var
   xd,yd : longint;
   acc	 : longint;
begin
   xd := abs(x-a);
   yd := abs(y-b);
   acc := xd*xd + yd*yd;
   if ((xd>150) or (yd>150)) then
      distance := longIntSqrt(acc)
   else
      distance := intSqrt(acc);
end;


function fixedSqrt(num: word):word;
begin
    { an aproximation derived from  intsqrt}
    fixedSqrt := intsqrt(num) * scsqrt;
end;


end.
