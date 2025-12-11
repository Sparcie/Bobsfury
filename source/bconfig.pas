{bobs fury configuration unit - just stores and retrieves settings
in other units.}
{A Danson 2000}
unit Bconfig;


interface

procedure getConf;
procedure saveConf;

implementation
uses bobgraph,bsound,bsystem,engine,bjoy,keybrd,buffer;


procedure getConf;
var
   infile : reader;
   z,i	  : byte;
begin
   if not(checkfile('bob.cfg')) then
   begin
      soundon;
      useCustomKeys := true;
      {$ifndef XT}
      {standard keyboard and graphics mode}
      graphicsMode:=2;
      scancode[1] := 203; {left}
      scancode[2] := 205; {right}
      scancode[3] := 57; {fire}
      scancode[4] := 200; {jump}
      scancode[5] := 49; {select weapon}
      scancode[6] := 35; {use bottle}
      scancode[7] := 34; {toss grenade}
      {$else}
      { XT defaults for keyboard and graphics}
      graphicsMode:=0;
      scancode[1] := 75; {left}
      scancode[2] := 77; {right}
      scancode[3] := 57; {fire}
      scancode[4] := 72; {jump}
      scancode[5] := 49; {select weapon}
      scancode[6] := 35; {use bottle}
      scancode[7] := 34; {toss grenade}
      {$endif}
      gap:=2;
      diff:=3;
      respawn:=false;
      usejoy:=false;
      musico:=false;
      volume := $0B;
      exit;
   end;
   infile.open('bob.cfg');
   graphicsMode := ord(infile.readChar);
   z:= ord(infile.readChar);
   soundo:=true;
   if z=$00 then soundo:=false;
   z:= ord(infile.readChar);
   gap:=z;
   z:= ord(infile.readChar);
   diff:=z;
   if diff=255 then diff:=-3;
   z:= ord(infile.readchar);
   respawn:=false;
   if (z=$FF) then respawn:=true;
   force:= ord(infile.readChar);
   volume := ord(infile.readChar);
   usejoy:=true;
   z:=ord(infile.readChar);
   if (z=$00) then usejoy:=false;
   musico:=true;
   z:=ord(infile.readChar);
   if (z=$00) then musico:=false;
   if (musico) then musicon;
   z:=ord(infile.readChar);
   useCustomKeys:=false;
   if (z=$FF) then useCustomKeys:=true;
   {read the keyscan codes (of which there are 7)}
   for i:=1 to 7 do
   begin
      scancode[i]:= ord(infile.readChar);
   end;
   {read the joystick button configuration}
   for i:= 1 to 4 do
   begin
      jcbuttons[i] := ord(infile.readChar);
   end;
   infile.close;
end;

procedure saveConf;
var outfile : writer;
    z,i	    : byte;
    a	    : char;
begin
   if not(canWriteTo('bob.cfg')) then
   begin
      writeln('Cannot write config file');
      exit;
   end;
   outfile.open('bob.cfg');
   outfile.writeChar(chr(graphicsMode));
   z:=$00;
   if soundo then z:=$01;
   outfile.writeChar(chr(z));
   outfile.writeChar(chr(gap));
   z:=diff;
   if diff=-3 then z:=$ff;
   outfile.writeChar(chr(z));   
   z:=0;
   if respawn then z:=$FF;
   outfile.writeChar(chr(z));
   outfile.writeChar(chr(force));
   z:=$0f;
   if (isBlaster) then z:=volume;
   outfile.writeChar(chr(z));
   z:=$00;
   if usejoy then z:=$FF;
   outfile.writeChar(chr(z));
   z:=$00;
   if musico then z:=$FF;
   outfile.writeChar(chr(z));
   z:=$00;
   if useCustomKeys then z:=$FF;
   outfile.writeChar(chr(z));
   for i:= 1 to 7 do
   begin
      outfile.writeChar(chr(scancode[i]));
   end;
   for i:= 1 to 4 do
   begin
      outfile.writeChar( chr(jcbuttons[i]));
   end;
   outfile.close;
end;
end.
