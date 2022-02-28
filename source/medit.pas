{Music editor program for the bobs fury music format
 A Danson Dec 2005
 put on hold, implementing a simple converter}

{reimplementing as a graphical editor 2012}

{Changed my mind, going back to a text mode based editor 2019}

{$G+}
{$N+}
{$E+}
{$R+}

program medit;

uses crt,dos,bmusic,sbiibk,fmplayer,bsystem;

var
   cursor    : integer; {the location of the cursor within the current channel}
   currentch : word; {The current channel that we are working with.}
   usableRam : longint;{a measure of how much ram is available for use}
   pom	     : boolean; {play the note under the cursor upon moving it }

const
   notes : array[ 0..12] of string[3] = ('--', 'C#', 'D ', 'D#','E ', 'F ', 'F#', 'G ', 'G#', 'A ', 'A#', 'B ', 'C ');


procedure listfiles(ext :string);
var  DirInfo : SearchRec;
     x,y     : integer;
begin
   x:=1; y:=2;
   FindFirst('*.'+ext,0, DirInfo);
  while DosError = 0 do
  begin
     gotoxy(x,y);
     write(DirInfo.Name);
     x:=x+13;
     if (x>66) then
     begin
	x:=1;
	y:=y+1;
     end;
    FindNext(DirInfo);
  end;
end; { listfiles }

function input(x,y:integer):string;
var
   z,s : string;
   done : boolean;
   a: char;
   i: integer;  
begin
   z:='';
   done:=false;
   while not(done) do
   begin
      while not(keypressed) do;
      a:=readkey;
      textcolor(0);
      s:=z+'_';
      gotoxy(x,y);
      write(s);
      if not((a=char(13)) or (a=char(8)) ) then z:=z+a;
      if a=char(13) then done:=true;
      if a=char(8) then
      begin
	 s:=z;
	 z:='';
	 for i:= 1 to length(s)-1 do z :=z + s[i];
      end;
      textcolor(7);
      s:=z+'_';
      gotoxy(x,y);
      write(s);
   end;
   input:=z;
end;

{ Starts a new file! You need to select the number of channels }
procedure new;
var
   i,c	: byte;
   s	: string;
   done	: boolean;
   k	: char;
   n	: note;
begin
   clrScr;
   textColor(7);
   gotoxy(1,1);
   writeln('Please select how many channels you want in the new file.');
   for i:= 1 to 5 do
   begin
      writeln(' ',i);
   end;
   i:=1;
   done:=false;
   gotoxy(1,i+1);
   write('*');
   while not(done) do
   begin
      while not(keypressed) do ;
      gotoxy(1,i+1);
      write(' ');
      k := readkey;
      if k = chr(13) then done:=true;
      if k = chr(27) then exit;
      if k = chr(0) then
      begin
	 k := readkey;
	 if (k = chr(72)) and (i>1) then i:= i-1;
	 if (k = chr(80)) and (i<5) then i:= i+1;
      end;
      gotoxy(1,i+1);
      write('*');
   end;
   {selection made!}
   newFile(i);
   channel(0);
   n.oct:=3;
   n.note:=1;
   n.leng:=4;
   for c:=1 to i do
      begin
	 channel(c);
	 insert;
	 setNote(n);
      end;
   cursor := 0;
   currentch := 1;
end;

procedure drawCursor(c : integer); {draw the note that is the cursor c = colour }
var
   x,y	    : integer;
   page,pos : integer;
   n	    : note;
   s	    : string;
   z	    : boolean;
begin
   page := cursor div 26;
   pos := cursor mod 26;

   x:= 1 + (pos*3);
   y:= currentch * 4;

   if not(moveto(cursor)) then exit ;

   textcolor(c);
   
   getNote(n);
   gotoxy(x,y);
   write(notes[n.note]);
   gotoxy(x,y+1);
   str(n.oct,s);
   write(s);
   gotoxy(x,y+2);
   str(trunc(n.leng),s);
   write(s + ' ');
end;

procedure drawChannel(c	: integer); { draw the channel c at the current cursor. }
var x,y	 : byte;
   page	 : integer;
   count : integer;
   n	 : Note;
   s	 : string;
begin
   textcolor(7);
   x := 1;
   y := c * 4;
   count := 0;

   page := cursor div 26;
   channel(c);

   if not(moveto(page*26)) then exit;

   if (notecount < (page*26)) then exit;

   repeat
      getNote(n);
      gotoxy(x,y);
      write(notes[n.note]);
      gotoxy(x,y+1);
      str(n.oct,s);
      write(s);
      gotoxy(x,y+2);
      str(trunc(n.leng),s);
      write(s+' ');
      
      x:=x+3;
      inc(count);
   until ((not(next) or (count=26)));

   if (count < 26) then
   begin {erase the remainder of the screen!}
      while (count<26) do
	 begin
	    gotoxy(x,y);
	    write('  ');
	    gotoxy(x,y+1);
	    write('  ');
	    gotoxy(x,y+2);
	    write('  ');
	    x:= x+3;
	    inc(count);
	 end;
   end;
end;	  

procedure drawstatus;
var
   s	: string;
   used	: longint;
begin
   gotoxy(1,1);
   textcolor(7);
   write(' cursor:');
   str(cursor,s);
   write(s+ ',');
   str(currentch,s);
   write(s+ ' ');
   textcolor(8);
   if pom then textcolor(15);
   write(' POM ');
   textcolor(7);
   write(' mem:');

   used := usableram - memavail;
   str(used, s);
   write(s + ' of ');
   str(usableram,s);
   write(s + '    ');
   
end;

{initialises the display system.}
procedure initDisplay;
var
   ch:integer;
begin
   clrscr;
   gotoxy(1,1);
   for ch:= 1 to channelCount do
      begin
	 channel(ch);
	 write(noteCount,' ');
      end;
   for ch := 1 to channelCount do
      drawChannel(ch);
   channel(currentch);
   drawcursor(9);
   drawstatus;	  
end;

procedure mainLoop;
var a	    : char;
    running : boolean;
    n	    : Note;
begin
  running:=true;
  while running do
  begin
    while not(keypressed) do ; {wait until a key is pressed}
    a:= readkey; 
    a := upcase(a);
    if a='Q' then running:=false;
    if a='P' then play;
    if a=' ' then pom := not(pom);
    if a=chr(0) then
       begin
	  a:=readkey;
	  if a = chr(72) then {up }
	     if currentch > 1 then
	  begin
	     drawcursor(7);
	     dec(currentch);
	     cursor:=0;
	     drawchannel(currentch);
	     drawcursor(9);
	  end;
	  if a = chr(80) then {down}
	     if currentch < channelcount then
	  begin
	     drawcursor(7);
	     inc(currentch);
	     cursor:=0;
	     drawchannel(currentch);
	     drawcursor(9);
	  end;
	  if a = chr(82) then {insert}
	  begin
	     n.oct := 3;
	     n.note := 0; {default to a rest}
	     n.leng := 4; {default to a crotchet}
	     drawcursor(7);
	     insert;
	     setNote(n);
	     inc(cursor);
	     drawchannel(currentch);
	     drawcursor(9);
	  end;
	  if a = chr(83) then {delete}
	     if noteCount > 1 then
	  begin
	     drawcursor(7);
	     remove;
	     if cursor>(notecount-1) then cursor := notecount-1;
	     drawchannel(currentch);
	     drawcursor(9);	     
	  end;
	  if a = chr(75) then {left}
	  begin
	     drawcursor(7);
	     if prev then
	     begin
		if pom then
		begin
		   getNote(n);
		   addNoteRecord(n,currentch+3);
		end;	     
		dec(cursor);
		if (cursor mod 26) = 25 then drawChannel(currentch);
	     end;
	     drawcursor(9);
	  end;
	  if a = chr(77) then {right}
	  begin
	     drawcursor(7);
	     if next then
	     begin
		if pom then
		begin
		   getNote(n);
		   addNoteRecord(n,currentch+3);
		end;	     
		inc(cursor);
		if (cursor mod 26) = 0 then drawChannel(currentch);
	     end;
	     drawcursor(9);
	  end;
	  if a = chr(81) then {pgdown}
	     if (cursor+26 < notecount) then
	     begin
		cursor := cursor + 26;
		drawchannel(currentch);
		drawcursor(9);
	     end;
	  if a = chr(73) then {pgup}
	     if (cursor-26 > 0) then
	     begin
		cursor := cursor - 26;
		drawchannel(currentch);
		drawcursor(9);
	     end;
       end;
     drawstatus;
  end;
end;

begin
   fmplayer.start;
   pom := false;
   usableRam := memavail;
   cursor:=0;
   currentch:=1;
   if (paramcount=0) then      
      new
   else
      begin
	 if (checkfile(paramstr(1))) then
	    load(paramstr(1))
	 else
	    begin
	       writeln(paramstr(1),' not found');
	       halt(1);
	    end;
      end;
   initDisplay;
   play;
   mainLoop;
   fmplayer.stop;
end.

