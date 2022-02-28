{Sound Effects Cache }
{ A Danson 2014 }

{this unit is for storing sound effects and playing them directly via the
fmplayer unit. Sound effects can be stored and loaded from a file for
convenience. fmmusic can also output to this unit.}

unit scache;

interface

uses fmplayer;

{the playback and loading interface}
procedure load(fle : string);
procedure playSound(s : integer; ch:byte);

{ creation code - used by fmmusic, but can be used directly }
procedure initialise; {set up a new file and the first sound.}
procedure nextSound;
procedure addnote(n :  note);
procedure save(fle    : string);

implementation

const 
   maxSounds = 11; {change this to change the max number of sounds stored}
   maxLength = 18; {the maximum number of notes}

type
   sound    = record
		 data : array[1..maxLength] of note;
		 size : integer;
	      end;    
   soundptr = ^sound;

var {general purpose and playback}
   sounds   : array[1..maxSounds] of soundptr;
   sCount   : integer;
   loaded   : boolean;
   exitsave : pointer;

{the playback and loading interface}
procedure load(fle : string);
var
   inf : file;
     i : integer;
   rc  : integer;
begin
   if loaded then
   begin
      for i:= 1 to sCount do
	 dispose(sounds[i]);
   end;
   assign(inf,fle);
   reset(inf,1);
   blockRead(inf,scount,sizeOf(integer),rc);
   if not(rc=sizeof(integer)) then
      halt(2);
   for i:= 1 to scount do
   begin
      new(sounds[i]);
      blockRead(inf,sounds[i]^,sizeof(sound),rc);
      if not(rc=sizeof(sound)) then
	 halt(2);
   end;
   close(inf);
   loaded := true;
end; { load }

procedure playSound(s : integer; ch : byte);
var
   i : integer;
begin
   {if not(loaded) then exit;}
   with sounds[s]^ do
   begin
      for i:= 1 to size do
	 addNoteRecord(data[i],ch);
   end;
end; { playSound }

{ creation code - used by fmmusic, but can be used directly }
procedure initialise; {set up for a new file and the first sound.}
begin
   loaded := true;
   new(sounds[1]);
   sounds[1]^.size := 0;
   scount := 1;
end; { initialise }

procedure nextSound;
begin
   if scount=maxSounds then exit;
   inc(scount);
   new(sounds[scount]);
   sounds[scount]^.size:=0;
end; { nextSound }

procedure addnote(n :  note);
begin
   with sounds[scount]^ do
   begin
      if size=maxLength then exit;
      inc(size);
      data[size] := n;
   end;
end;

procedure save(fle : string);
var
   ouf : file;
   i   : integer;
begin
   assign(ouf,fle);
   rewrite(ouf,1);
   blockWrite(ouf,scount,sizeof(integer));
   for i:= 1 to scount do
      blockWrite(ouf,sounds[i]^,sizeof(sound));
   close(ouf);
end;

{$f+}
procedure unload;
var
   i : integer;
begin
   if loaded then
      for i:= 1 to sCount do
	 dispose(sounds[i]);
   loaded := false;
   exitproc:= exitsave;
end;
{$f-}
   
begin
   loaded:=false;
   exitsave:=exitproc;
   exitproc := @unload;
end.