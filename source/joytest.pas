program joytest;

uses bjoy,crt;

var a:char;
begin
   clrscr;
while not(keypressed) do {keypressed}
   begin
      update;
      gotoxy(1,1);
      write(joyavail); writeln('  ');
      write(joy.xaxis); writeln('  ');
      write(joy.yaxis); writeln('  ');
      write(joy.buttons); writeln('  ');
      {write(joy1.buttonb); writeln('  ');
      write(joy2.xaxis); writeln('  ');
      write(joy2.yaxis); writeln('  ');
      write(joy2.buttona); writeln('  ');
      write(joy2.buttonb); writeln('  ');}
   end;
   a:=readkey;
end.
