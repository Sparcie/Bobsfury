{converts qbasic play statements into bobsfury music files}
{$G+}
program MusicConverter;

uses bmusic,fmmusic,synthint,dos;

var fname:array[0..100] of string;
    num,up:integer;

procedure det;
var name:string;
  DirInfo: SearchRec;
begin
  FindFirst('*.txt',0, DirInfo);
  while DosError = 0 do
  begin
    fname[num]:=Dirinfo.Name;
    Write(fname[num]+' ');
    num:=num+1;
    FindNext(DirInfo);
  end;
end; { det }

function number(st : string):integer;
var
   i,res : integer;
begin
   number:=0;
   res:=0;
   i:=0;
   {find the start of the number}
   while not(st[i] in ['0'..'9']) do inc(i);
   while st[i] in ['0' .. '9'] do
   begin
      res:=res*10;
      res:=res + (ord(st[i])-ord('0'));
      i:=i+1;
   end; 
   number:=res;
end;

procedure convert(fle:string);
var
   inf	: text;
   tm	: string;
   i,ch	: integer;
   r	: boolean;
begin
   setTarget(music);
   assign(inf,fle);
   reset(inf);
   {read channel count}
   readln(inf,tm);
   ch:=number(tm);
   writeln(ch,' Channels');
   if ch=0 then
   begin
      writeln('No Channels- Invalid file');
      exit;
   end;
   newfile(ch);
   i:=0;

   {read the channels and write them to the bfm}
   while ( (i<ch) and not(eof(inf))) do
   begin
      channel(i+1);
      writeln('Channel ',i+1);
      setInstrument(default1);	      
      readln(inf,tm); {read first line}
      writeln('ch:',tm);
      {check if this is a instrument selector
      (only the three stored instruments are valid see synthint)}
      if tm[1]='*' then
      begin
	 if tm[2]='1' then setInstrument(default1);
	 if tm[2]='2' then setInstrument(default2);
	 if tm[2]='3' then setInstrument(default3);
      end
      else
	 playMusic(tm,i+4);
      {ok read lines and send them through until we hit three *}
      r:=false;
      while (not(r) and not(eof(inf))) do
      begin
	 readln(inf,tm);
	 writeln('pl:',tm);
	 if pos('***',tm)>0 then r:=true
	 else
	    playMusic(tm,i+4);
      end;
      i:=i+1;
   end;   
   close(inf);
   r:=false;
   tm:='';
   for i:=1 to 12 do
   begin
      if fle[i]='.' then r:=true;
      if not(r) then tm:=tm+fle[i];
   end;   
   tm:=tm+'.bfm';
   save(tm);
   writeln('playing...');
   play;
   wait;
end;

begin
   num:=0;
   det;
   writeln;
   up:=0;
   for up:=0 to (num-1) do
   begin
      writeln('converting '+fname[up]+'....');
      convert(fname[up]);
   end; { MusicConverter }
   {writeln('reloading list and playing');
   loadlist('.\');
   changesong;
   while isplaying do ;}
end.
