{common sound unit for bobsfury!}
{A Danson 2000}

{Define noAdlib to remove adlib/soundblaster support}

{$I defines.pas}

unit bsound;

 interface
  procedure gethealth;
  procedure shoot;      {*}
  procedure flyerbomb;
  procedure grenade;
  procedure lbolt;
  procedure losehealth;  {*}
  procedure xplode;      {*}
  procedure die;
  procedure gettreasure;
  procedure invuln;
  procedure showmonst;     {*}
  procedure hidemonst;     {*}
  procedure soundon;
  procedure soundoff;
  procedure musicon;
  procedure musicoff;
  function isBlaster:boolean;
  procedure checkSongChange;
  procedure initSound;
   
  var soundo,musico : boolean;
     volume	    : byte;
     force	    : byte;
 {force audio 0 - auto detect adlib 1 - PC speaker 2 - no sound 
  3 - LPT1 opl3lpt 4 - LPT2 opl3lpt }

implementation

  uses music
     {$ifndef noAdlib}
     ,scache,fmplayer,synthint,bmusic
     {$endif};

procedure initSound;
begin
   {$ifndef noAdlib}
   if (force=0) then
      if adlibDetected then
      begin
	 start;
	 fmplayer.setmasterVol($0C);
	 fmplayer.setfmvol(volume);
	 setMusicType(legato,1);
	 setMusicType(legato,2);
	 setMusicType(legato,3);
	 setChannel(default2,1);
	 setChannel(default2,2);
	 setChannel(default2,3);
	 loadlist('MUSIC\');
	 scache.load('bob.snd');
      end;
   if (force=3) or (force=4) then
   begin
      setdevice(force-2);
      if adlibDetected then start;
      setMusicType(legato,1);
      setMusicType(legato,2);
      setMusicType(legato,3);
      setChannel(default2,1);
      setChannel(default2,2);
      setChannel(default2,3);
      loadlist('MUSIC\');
      scache.load('bob.snd');
   end;
   {$endif}
end;

  
procedure checkSongChange; 
begin
   {$ifndef noAdlib}
   if musico then bmusic.checkSongChange;
   {$endif}
end;

function soundString(t : integer):string;
var
   s : string;
begin
   s := '';
   case t of
     1	: s:= 'l96n50n55n60n65'; {shoot}
     2	: s:= 'l96n50n55n50'; {flyer bomb}
     3	: s:= 'l19n45n43n40'; {grenade}
     4	: s:= 'l96n68n70n68n72'; {lightning bolt}
     5	: s:= 'l96n50n53n54n55'; {health pickup}
     6	: s:= 'l96n55n54n53n52n51n50n49';{player hurt}
     7	: s:= 'l64n5n3n4n6n1n3n2'; {explosion}
     8	: s:= 'l96n55n56n57n58n59n60n61';{treaure pickup}
     9	: s:= 'l96n52n53n54n55n56n57n58n59n60n61n6n2n63n64n65';{invulnerability pickup}
     10	: s:= 'l19n68n71n74n78'; {teleport in or monster appear}
     11	: s:= 'l19n78n74n71n68';  {teleport out or monster disappear}
   end; { case }
   soundString:=s;
end;

procedure play(t:integer);
var c : byte;
   ln : integer;
   s  : string;
begin 
   if force=2 then exit;
   if soundo then
      {$ifndef noAdlib}   
      if ((force=0) and isBlaster) or ((force=3) or (force=4)) then
      begin
	 c:=1;
	 if (bufferSize(1)>0) then c:=2;
	 if ((bufferSize(2)>0) and (c=2)) then c:=3;
	 if ((bufferSize(3)>0) and (c=3)) then
	 begin
	    {all our buffers have data in them... which one should we use?}
	    c:= 1;
	    ln := bufferSize(1);
	    if (bufferSize(2)<ln) then
	    begin
	       ln := bufferSize(2);
	       c:=2;
	    end;
	    if (bufferSize(3)<ln) then
	    begin
	       ln := bufferSize(3);
	       c:=3;
	    end;
	    clearChannel(c);
	 end;
	 scache.playSound(t,c);
      end
      else
	 {$endif}
	 music.playmusic(soundString(t));
end;

procedure shoot;
begin
   PLAY(1);
end; { shoot }

procedure flyerbomb;
begin
   play(2);
end;

procedure grenade;
begin
   play(3);
end; { grenade }

procedure lbolt;
begin
   play(4);
end;

procedure gethealth;
begin
   play(5);
end;

procedure losehealth;
begin
   PLAY(6);
end;

procedure xplode;
begin
   PLAY(7);
end;

procedure die;
begin
   losehealth;
   xplode;
end;

procedure gettreasure;
begin
   PLAY(8);
end;

procedure invuln;
begin
   PLAY(9);
end;

procedure showmonst;
begin
   PLAY(10);
end;

procedure hidemonst;
begin
   PLAY(11);
end;

procedure soundon;
begin
   soundo:=true;
end;

procedure soundoff;
begin
   soundo:=false;
end;

procedure musicOn;
begin
   {$ifndef noAdlib}
   if not(isBlaster) then exit;
   loadlist('MUSIC\');
   changesong;
   musico:=true;
   {$endif} 
end;

procedure musicoff;
begin
   {$ifndef noAdlib} 
   stop;
   {$endif} 
   musico:=false;
end;

function isBlaster:boolean;
var b : boolean;
begin 
   isblaster:=false;
   {$ifndef noAdlib}
   if not(force=0) then exit;
   b:=(soundDevice=1);
   isBlaster:=b;
   {$endif}
end;

begin
   soundo:=true;
   musico:=false;
   force:=0;
end.
