{ Graphic file packer for the PGS system version 2 to include RLE }
{ A Danson 2014 }

program packer;

uses bsystem, gpack, buffer;

var
   r	 : reader; {file reader}
   names : array[1..200] of string[16]; {list of sprites}
   num	 : integer;
   sx,sy : integer;
   tx,ty : integer;
   i	 : integer;
   s	 : string;

begin
   writeln('Graphic file packer A Danson 2014 ver 2.0');
   writeln('usage: packer listfile pakfilename');
   if paramcount<2 then halt(1);
   r.open(paramstr(1));
   num := 0;
   while not(r.eof) do
   begin
      inc(num);
      if (num>200) then
	 begin
	    writeln('Too many sprites! limit = 200');
	    halt(1);
	 end;
      names[num] := r.readln;
   end;
   r.close;
   writeln('list read ok, checking files exist...');
   for i:= 1 to num do
   begin
      if not(checkfile(names[num])) then
      begin
	 writeln(names[num] + ' not found!');
      end;
   end;
   {load the first file! we need this for the size!}
   r.open(names[1]);
   sx := ord(r.readChar);
   sy := ord(r.readChar);
   newFile(paramstr(2),num,sx,sy);
   while not(r.eof) do
      spriteData(r.readChar);
   r.close;
   write('.');
   {read the remaining files}
   for i:= 2 to num do
   begin
      r.open(names[i]);
      tx := ord(r.readChar);
      ty := ord(r.readChar);
      if not((tx=sx) and (ty=sy)) then
      begin
	 writeln('bad size for '+names[i]);
	 halt(1);
      end;
      while not(r.eof) do
	 spriteData(r.readChar);
      r.close;
      write('.');
   end;
   writeln;

   i:= closeFile;
   str(num,s);
   writeln('Sprites - '+s);
   str(i,s);
   writeln('Compressed - '+s);
end.
