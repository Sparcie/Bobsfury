program keytest;

uses keybrd,crt;

var
   a : char;
   i : word;
begin
   scancode[1] := 1;
   scancode[2] := 14;
   scancode[3] := 59;
   scancode[4] := 57424;
   scancode[5] := 57416;
   scancode[6] := 57419;
   scancode[7] := 57421;
   clrScr;
   a:='a';
   while a<>'Q' do
   begin
      gotoXY(1,1);
      for i:= 1 to 7 do
	 write(' ',pressed[i]);
      writeln('     ');
      if keypressed then
      begin
	 a:=readkey;
	 writeln('ascii ',a,'           ');
	 writeln('keyface ',keyface(lastKeypressed),'         ');
	 writeln('scancode (dec) ',lastKeypressed,'            ');
      end;      
   end;   
end.