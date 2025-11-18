program joytest;

uses bjoy,crt;

var a:char;
begin
   clrscr;
while not(keypressed) do {keypressed}
   begin
      update;
      gotoxy(1,1);
      write(joyavail); writeln(' avail   ');
      write(joy.xaxis); writeln(' x axis  ');
      write(joy.yaxis); writeln(' y axis  ');
      write(joy.xcentre); writeln(' x centre   ');
      write(joy.ycentre); writeln(' y centre   ');
      write(joy.xdeadzone); writeln(' x deadzone    ');
      write(joy.ydeadzone); writeln(' y deadzone    ');
      write(joy.xmin); writeln(' x min   ');
      write(joy.ymin); writeln(' y min   ');
      write(joy.xmax); writeln(' x max   ');
      write(joy.ymax); writeln(' y max   ');
      write(xcentred); writeln('  x centred ');
      write(ycentred); writeln('  y centred ');
      write(abs(Integer(joy.xaxis) - Integer(joy.xcentre))); writeln(' x delta   ');
      write(abs(Integer(joy.yaxis) - Integer(joy.ycentre))); writeln(' y delta   ');      
      write(joy.buttons); writeln('  ');
      {write(joy1.buttonb); writeln('  ');
      write(joy2.xaxis); writeln('  ');
      write(joy2.yaxis); writeln('  ');
      write(joy2.buttona); writeln('  ');
      write(joy2.buttonb); writeln('  ');}
   end;
   a:=readkey;
end.
