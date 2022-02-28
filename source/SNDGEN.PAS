{program to generate bob's fury adlib sound file}
{A Danson 2014}

program sndgen;

uses scache, fmmusic;

var
   i : integer;

function soundString(t : integer):string;
var
   s : string;
begin
   s := '';
   case t of
     1	: s:= 'l96n50n55n60n65'; {shoot}
     2	: s:= 'l96n50n55n50'; {flyer bomb}
     3	: s:= 'l19n45n43n40'; {grenade}
     4	: s:= 'l96n68n70n68n72'; {lightning bolt}
     5	: s:= 'l96n50n53n54n55'; {health pickup}
     6	: s:= 'l96n55n54n53n52n51n50n49';{player hurt}
     7	: s:= 'l64n5n3n4n6n1n3n2'; {explosion}
     8	: s:= 'l96n55n56n57n58n59n60n61';{treaure pickup}
     9	: s:= 'l96n52n53n54n55n56n57n58n59n60n61n6n2n63n64n65';{invulnerability pickup}
     10	: s:= 'l19n68n71n74n78'; {teleport in or monster appear}
     11	: s:= 'l19n78n74n71n68';  {teleport out or monster disappear}
   end; { case }
   soundString:=s;
end;

begin
   setTarget(cache);
   initialise;
   for i:= 1 to 11 do
   begin
      playmusic(soundString(i),0);
      nextSound;
   end;
   scache.save('bob.snd');
end.
