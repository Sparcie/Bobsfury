program keytest;

uses keybrd{,crt};

var
   a : char;
   i : word;
begin
   scancode[1] := 1;
   scancode[2] := 14;
   scancode[3] := 59;
   scancode[4] := 2;
   scancode[5] := 3;
   scancode[6] := 4;
   scancode[7] := 5;
{   clrScr;}
   a:='a';
   while a<>'Q' do
   begin
{      gotoXY(1,1);
      for i:= 1 to 7 do
	 write(' ',pressed(i));
      writeln('     ');}
      if keybrd.keypressed then
      begin
	 a:=keybrd.readkey;
	 writeln('ascii ',a,'    ', ord(a),'   ');
	 writeln('keyface ',keyface(lastKeypressed),'         ');
	 writeln('scancode (dec) ',lastKeypressed,'            ');
      end;      
   end;   
end.
