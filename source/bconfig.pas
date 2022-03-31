{bobs fury configuration unit - just stores and retrieves settings
in other units.}
{A Danson 2000}
unit Bconfig;


interface

procedure getConf;
procedure saveConf;

implementation
uses bobgraph,bsound,bsystem,engine,bjoy,keybrd;


procedure getConf;
var conf:file of char;
   h,s:boolean;
   z,i:byte;
   a:char;
begin
   if not(checkfile('bob.cfg')) then
   begin
      soundoff;
      graphicsMode:=2;
      gap:=2;
      diff:=5;
      respawn:=false;
      usejoy:=false;
      musico:=false;
      exit;
   end;
   assign(conf,'bob.cfg');
   reset(conf);
   read(conf,a);
   z:= ord(a);
   graphicsMode := z;
   read(conf,a);
   z:= ord(a);
   s:=true;
   if z=$00 then s:=false;
   soundo:=s;
   read(conf,a);
   z:= ord(a);
   gap:=z;
   read(conf,a);
   z:= ord(a);
   diff:=z;
   if diff=255 then diff:=-3;
   read(conf,a);
   respawn:=false;
   if (a=chr($FF)) then respawn:=true;
   read(conf,a);
   force:= ord(a);
   read(conf,a);
   volume := ord(a);
   usejoy:=true;
   read(conf,a);
   z:=ord(a);
   if (z=$00) then usejoy:=false;
   musico:=true;
   read(conf,a);
   z:=ord(a);
   if (z=$00) then musico:=false;
   if (musico) then musicon;
   read(conf,a);
   z:=ord(a);
   useCustomKeys:=false;
   if (z=$FF) then useCustomKeys:=true;
   {read the keyscan codes (of which there are 7)}
   for i:=1 to 7 do
   begin
      read(conf,a);
      z:=ord(a);
      scancode[i]:= z;
   end;
   {read the joystick button configuration}
   for i:= 1 to 4 do
   begin
      read(conf,a);
      jcbuttons[i] := ord(a);
   end;

  close(conf);  
end;

procedure saveConf;
var conf:file of char;
    h,s:boolean;
    z,i:byte;
    a:char;
begin
   assign(conf,'bob.cfg');
   rewrite(conf);
   z:=graphicsMode;
   a:=chr(z);
   write(conf,a);
   z:=$00;
   if soundo then z:=$01;
   a:=chr(z);
   write(conf,a);
   a:=chr(gap);
   write(conf,a);
   z:=diff;
   if diff=-3 then z:=$ff;
   a:=chr(z);
   write(conf,a);
   a:=chr(0);
   if respawn then a:=chr($FF);   
   write(conf,a);
   a:= chr(force);
   write(conf,a);
   a:=chr($0f);
   if (isBlaster) then a:=chr(volume);
   write(conf,a);
   a:=chr($00);
   if usejoy then a:=chr($FF);
   write(conf,a);
   a:=chr($00);
   if musico then a:=chr($FF);
   write(conf,a);
   a:=chr($00);
   if useCustomKeys then a:=chr($FF);
   write(conf,a);
   for i:= 1 to 7 do
   begin
      a := chr(scancode[i]);
      write(conf,a);
   end;
   for i:= 1 to 4 do
   begin
      a:= chr(jcbuttons[i]);
      write(conf,a);
   end;
  close(conf);
end;
end.
