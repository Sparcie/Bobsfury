
uses synthint,fmsynth,crt,fmplayer;
 var s:boolean;
     i,c,z:integer;
{$f+}
procedure refill(ch : byte);
begin
   write('refill! ');
   writeln(ch);
    for c:=0 to 7 do
 for i:=1 to 12 do
 begin
   addnote(c,i,1,4);
 end;
 for c:=0 to 7 do
 for i:=1 to 12 do
 begin
    addnote(c,i,1,8);
 end;  
end;
{$f-}

begin
 resetdevice;
 writeln(detect);
   synthint.setmastervol(9,9);
   synthint.setfmvol(9,9);
  writeln(getfmvol,' ',getmastervol);
 setchannel(default1,1,0);
 initryth;
    delay(3000);
writeln('bass drum');
 bass;
 delay(5000);
writeln('tom tom');
  tom;
 delay(5000);
writeln('cymbal');
  cymbal;
 delay(5000);
hihat;
writeln('hi hat');
 delay(5000);
snare;
writeln('snare');
 delay(5000);
 closeryth;
    
 start;
   refillbuffer:=refill;
   setriff(7,true);
   setrythm(true);
   refillalarm(1,true);
   for c:=1 to 5 do
   begin
      addnote(1,c,7,4);
   end;
   {
 for c:=0 to 7 do
 for i:=1 to 12 do
 begin
   addnote(c,i,1,4);
 end;
 for c:=0 to 7 do
 for i:=1 to 12 do
 begin
    addnote(c,i,1,8);
 end;}
 writeln('press enter to stop');
 
 readln;
 write('stop');
 resetdevice;

end.
