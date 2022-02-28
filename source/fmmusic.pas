
{A Danson 2003 fmmusic player...
 Accepts syntax that the play statement does in QBASIC and gwbasic
 with a few exceptions
}

unit fmmusic;

interface

procedure playMusic(s : string; c:byte); {play music to channel c}
function bufferSize(c : byte):word; {get the buffer size}
procedure setMusicType(mk : word; c:byte); {set the music type on channel c}
procedure setTempo(t:word);  { set the tempo of the music.}
procedure setTarget(t :word ); {set the target}

   const 
      legato	 = 8;
      normal	 = 7;
      stacato	 = 6;
      defaultOct = 4;
      player	 = 1000;
      music	 = 1001;
      cache	 = 1002;

implementation

uses fmplayer,bmusic,scache;

var		 
   defaultLength : word;
   defaultKind	 : word;
   musicString	 : string;
   musicHere	 : word;
   target	 : word;



procedure sendnote(oct,note,channel : byte; len:real);
var temp : fmplayer.note;
    b	 : boolean;
begin
   if target=1000 then
      fmplayer.addnote(oct,note,channel,len);
   if target=1001 then
   begin
      while next do ;
      insert;
      temp.oct:=oct;
      temp.note:=note;
      temp.leng:=len;
      setNote(temp);
   end;
   if target=1002 then
   begin
      temp.oct:=oct;
      temp.note:=note;
      temp.leng:=len;
      scache.addNote(temp);
   end;
end; { sendnote }

function getChar:char;
begin
    getChar:=' ';
    if (musicHere > length(musicString)) then exit;
    getChar := MusicString[MusicHere];
    inc(MusicHere);
end;

function peekChar:char;
begin
    peekChar:=' ';
    if (musicHere > length(musicString)) then exit;
    peekChar := MusicString[musicHere];
end;

function GetNumber(min, max, default : word) : word;
{ Get a number from the MusicString, starting at MusicHere. Increment MusicHere
  past the end of the number. If the number is <min or >max then the default
  number is returned. This routine will also skip the Basic syntax for a
  variable: '=name;'
  based on code from J C Kessels }
var
   n	: word;
   temp	: char;
begin
   {Ignore Basic syntax for embedded variable instead of constant, and exit with
   the default. }
   if peekchar = '=' then
   begin
      while ((peekchar <> ';') and (musicHere<length(musicString)))
	 do temp := getchar;
      if peekchar = ';'
	 then temp := getchar;
      GetNumber := default;
      exit;
   end;

   { Accept a number from the MusicString. The number is finished by anything that
   is not a number '0'..'9'. }
   n := 0;
   temp:= peekchar;
   while (temp in ['0'..'9']) do
   begin
      n := (n * 10) + (Ord(getchar) - Ord('0'));
      temp:=peekchar;
   end;

   { Test if the number is within range, otherwise return the default. }
   if (n < min) or (n > max)
      then GetNumber := default
   else GetNumber := n;
end;

function getDots:word;
var temp:char;
begin
   getDots:=0;
   while ((musicHere < length(musicString)) and (peekChar='.')) do
   begin
      temp:=getChar;
      inc(getDots);
   end;
end;

procedure playMusic(s : string; c:byte);
var
   lengthset : word;
   oct	  : word;
   temp,temp2,temp3   : word;{temp variables for making notes}
   thisNote,nextChar: char;
   newNotel:real;
begin
   lengthset:=defaultLength;
   oct:=defaultOct;
   musicString:=s;
   musicHere:=1;
   while (musicHere < length(musicString)+1) do
   begin
        thisNote := getChar;
        thisNote := upCase(thisNote);
        if (thisNote='T') then  
        begin
            setTempo(getnumber(32,255,120));
        end;
        if (thisNote='O') then
        begin
          oct := getNumber(0,7,4);          
        end;
        if (thisNote='L') then
        begin
          lengthset:= getNumber(1,128,4);
        end;
        if (thisNote='M') then
        begin
             nextChar:= getChar;
             if (NextChar='S') then setMusicType(stacato,c);
             if (NextChar='L') then setMusicType(legato,c);
             if (NextChar='N') then setMusicType(normal,c);
        end;
        if (thisNote='N') then
        begin
           newNotel:=lengthset;
           temp:= getNumber(0,84,80);
           temp2 := temp mod 12;
           temp := temp div 12;
           if (temp2=0) then
                begin temp2:=12; dec(temp); end;
           temp3:=getDots;
           while (temp3>0) do
           begin dec(temp3); newNotel:=newNotel * 0.75; end;
           sendNote(temp,temp2,c,newNotel);
        end;
        if (thisNote='P') then
        begin
            newNotel := getNumber(1,64,lengthset);
            temp3:=getDots;
            while (temp3>0) do
            begin dec(temp3); newNotel:=newNotel * 0.75; end;
            sendNote(0,0,c,newNotel);
        end;
        if (thisNote='>') then
        begin
            inc(oct);
            if (oct>7) then oct:=7;
        end;
        if (thisNote='<') then
        begin
            dec(oct);
            if (oct>7) then oct:=0;
        end;
        if (thisNote='A') then
        begin
            temp := 9;
            if (peekChar='#') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='+') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='-') then begin dec(temp);nextchar:= getChar; end;
            newNotel := getNumber(1,64,lengthset);
            temp3:=getDots;
            while (temp3>0) do
            begin dec(temp3); newNotel:=newNotel * 0.75; end;
            sendNote(oct,temp,c,newNotel);
        end;
        if (thisNote='B') then
        begin
            temp := 11;
            if (peekChar='#') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='+') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='-') then begin dec(temp);nextchar:= getChar; end;
            newNotel := getNumber(1,64,lengthset);
            temp3:=getDots;
            while (temp3>0) do
            begin dec(temp3); newNotel:=newNotel * 0.75; end;
            sendNote(oct,temp,c,newNotel);
        end;
        if (thisNote='D') then
        begin
            temp := 2;
            if (peekChar='#') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='+') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='-') then begin dec(temp);nextchar:= getChar; end;
            newNotel := getNumber(1,64,lengthset);
            temp3:=getDots;
            while (temp3>0) do
            begin dec(temp3); newNotel:=newNotel * 0.75; end;
            sendNote(oct,temp,c,newNotel);
        end;
        if (thisNote='E') then
        begin
            temp := 4;
            if (peekChar='#') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='+') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='-') then begin dec(temp);nextchar:= getChar; end;
            newNotel := getNumber(1,64,lengthset);
            temp3:=getDots;
            while (temp3>0) do
            begin dec(temp3); newNotel:=newNotel * 0.75; end;
            sendNote(oct,temp,c,newNotel);
        end;
        if (thisNote='F') then
        begin
            temp := 5;
            if (peekChar='#') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='+') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='-') then begin dec(temp);nextchar:= getChar; end;
            newNotel := getNumber(1,64,lengthset);
            temp3:=getDots;
            while (temp3>0) do
            begin dec(temp3); newNotel:=newNotel * 0.75; end;
            sendNote(oct,temp,c,newNotel);
        end;
        if (thisNote='G') then
        begin
            temp := 7;
            if (peekChar='#') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='+') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='-') then begin dec(temp);nextchar:= getChar; end;
            newNotel := getNumber(1,64,lengthset);
            temp3:=getDots;
            while (temp3>0) do
            begin dec(temp3); newNotel:=newNotel * 0.75; end;
            sendNote(oct,temp,c,newNotel);
        end;
        if (thisNote='C') then
        begin
            temp := 12;
            temp2:= oct;
            if (peekChar='#') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='+') then begin inc(temp);nextchar:= getChar; end;
            if (peekChar='-') then begin dec(temp);nextchar:= getChar; end;
            newNotel := getNumber(1,64,lengthset);
            temp3:=getDots;
            if (temp=12) then begin dec(temp2); end;
            if (temp>12) then begin temp:=temp-12; end;
            while (temp3>0) do
            begin dec(temp3); newNotel:=newNotel * 0.75; end;
            sendNote(temp2,temp,c,newNotel);
        end;
   end;
end; { playMusic }

function bufferSize(c : byte):word;
begin
   buffersize:=fmplayer.bufferSize(c);
end; { bufferSize }

procedure setMusicType(mk : word; c:byte);
begin
   fmplayer.setMusicType(mk,c);
end; { setMusicType }

procedure setTempo(t:word);
begin
    fmplayer.settempo(t);
end;

procedure setTarget(t : word);
begin
   target:=t;
end;

begin
   defaultKind:=7;
   defaultLength:=4;
   target:=player;
end.
