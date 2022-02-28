{ plays music using the adlib/sound blaster in the background}
{A Danson 2003 }
unit fmplayer;
interface
uses dos,synthint, pitdbl;

type
   chcallback = procedure(ch : byte);
   Note = record
	   oct	   : byte;
	   note	   : byte;
	   leng	   : real; {length of note (gwbasic style length)}
	end;	   

var 
   refillBuffer : chcallback;
   soundDevice: byte; {sound device present 0=none 1=adlib}

   procedure start;
   procedure stop;
   procedure clearChannel(c:byte);
   procedure setinstrument(i : instrument;ch:byte);
   procedure settempo(t:word);
   procedure addnote(oct,note,channel : byte;len:real);
   procedure addNoteRecord(n :note; channel : byte);
   procedure setmastervol(vol:byte);
   procedure setfmvol(vol:byte);
   function getmastervol:byte;
   function getfmvol:byte;
   function bufferfull(c :byte) :boolean;
   function buffersize(c :byte) : word;
   procedure setMusicType(mk: word; c:byte);

   procedure setRythm(r : boolean);
   procedure refillAlarm(ch : byte; on:boolean);

   function getTempo:word;
   function getMusicKind(ch:byte):word;

   function adlibDetected : boolean;
   
   const 
      legato  = 8;
      normal  = 7;
      stacato = 6;
   
implementation

const clockrate = 18.2; {timer chip rate hz}

type buffer	   = array[0..250,1..9] of note; 
     bufferPointer = ^buffer;
   
var
    oldint1c  : pointer; {interupt save}
    buff      : bufferPointer;	       
    {buff     : array[0..250,1..9] of note;  main buffer for notes}
    buffsize  : array[1..9] of word; {size of main buffer}
    buffptr   : array[1..9] of word; {next note to be played}
    buffhead  : array[1..9] of word; {the head where notes are to be inserted}
    musicKind : array[1..9] of word;
    refill    : array[1..9] of boolean;
    playing   : boolean; {is playing music from the buffer}
    cncycles  : array[1..9] of word; {store of current notes cycles left}
    cnote     : array[1..9] of note; {current note}
    tempo     : word;                   {more reading and limits on length}
    i,c	      : integer;   {misc}
    exitsave  : pointer;
    ryth      : boolean;
   inited     : boolean; {has the unit been installed}
 
procedure init; forward;

function getTempo:word;
begin
   getTempo:=tempo;
end; { getTempo }

function getMusicKind(ch : byte):word;
begin
   getMusicKind:= musicKind[ch];
end;

procedure refillAlarm(ch : byte; on:boolean);
begin
   refill[ch]:=on;
end;

procedure setRythm(r : boolean);
begin
   ryth:=r;
   if (r) then initryth;
   if not(r) then closeryth;
end;

procedure start;
begin   
   if soundDevice = 0 then exit;
   init;
   playing:=true;
end;

procedure stop;
begin
   playing:=false;
end;

procedure clearChannel(c:byte);
begin
   buffsize[c]:=0;
   buffptr[c]:=0;
   buffhead[c]:=0;
end;

procedure setinstrument(i:instrument;ch:byte);
begin
 setchannel(i,ch);
end;

procedure settempo(t:word);
begin
  if t<32 then exit;
  if t>255 then exit; 
  tempo:=t;
end;

procedure addNoteRecord(n :note; channel : byte);
begin
   if (bufferfull(channel) and refill[channel]) then exit;
   if soundDevice=0 then exit;
   if n.leng<=0 then exit;
   while (bufferfull(channel))  do  ;


   buff^[buffhead[channel],channel]:=n;
   inc(buffhead[channel]);
   if (buffhead[channel]=251) then buffhead[channel]:=0;
   inc(buffsize[channel]);


end;

procedure addnote(oct,note,channel:byte;len:real);
begin
   if (bufferfull(channel) and refill[channel]) then exit;
   if soundDevice=0 then exit;
   if len<=0 then exit;
   while (bufferfull(channel)) do  ; {wait until there is room in the buffer}
   

   buff^[buffhead[channel],channel].oct:=oct;
   buff^[buffhead[channel],channel].note:=note;
   buff^[buffhead[channel],channel].leng:=len;
   inc(buffhead[channel]);
   if (buffhead[channel]=251) then buffhead[channel]:=0;
   inc(buffsize[channel]);

end;

procedure setmastervol(vol:byte);
begin
 synthint.setmastervol(vol,vol);
end;

procedure setfmvol(vol:byte);
begin
 synthint.setfmvol(vol,vol);
end;

function getmastervol:byte;
begin
 getmastervol:=synthint.getmastervol;
end;

function getfmvol:byte;
begin
 getfmvol:=synthint.getfmvol;
end;

function bufferfull(c :byte) :boolean;
begin
   bufferfull:=false;
   if (buffersize(c)=251) then bufferfull:=true;
end;

function buffersize(c :byte) :word;
begin
   buffersize:=buffsize[c];
end; { buffersize }

function localRound(r : real):integer;
begin
   localround:=0;
   if r>maxint then exit;
   if r<-32767 then exit;
   localRound:=trunc(r);
   if (frac(r)>0.5) then localRound := trunc(r)+1;
end;

function noteticks(len : real):word; {length of note in ticks}
var
   musicdelay1 : word;
   r,t	       : real;  
begin
   r:= (len * tempo);
   t:= 4368.0 * pitRatio;
   if r>t then musicdelay1:=1 else
      if (r>0) then musicdelay1 := localRound((4368.0 * pitRatio) / r);
   noteticks:=musicdelay1;
end;


function notesilence(len:real;musickind : word):word; {silence in tick}
var
   musicdelay2: word;
begin
      if MusicKind < 8 then MusicDelay2 := (noteticks(len) * (8 - MusicKind)) div 8
      else MusicDelay2 := 0;
   notesilence:=musicdelay2;
   if (len=0) then notesilence:=0;
end; { notesilence }

procedure newint1c; interrupt;
var
   i : word;
begin
   Inline(                  {call old handler}
   $9C/                   {pushf}
   $FF/$1E/>OLDINT1C);    {call far [>OldInt1C]}
   {stuff to play music}
   if (playing) then
   begin
      

      for i:= 1 to 9 do
      begin
	 {phase 1 decrement counts for current notes (adds silence) }
	 if (cncycles[i] > 0) then
	 begin
	    dec(cncycles[i]);
	    if (cncycles[i]=0) then
	    begin
	       if ((i<7) or not(ryth)) then setnoteoff(i); {silence has begun}
	       cncycles[i]:=notesilence(cnote[i].leng,musicKind[i]);
	       cnote[i].leng:=0;
	    end;
	 end;
	 
	 {phase 2 check if there is an note in the buffer if so play it}
	 if (cncycles[i]=0 ) then
	    if (buffsize[i]>0) then 
	    begin
	       cnote[i]:=buff^[buffptr[i],i];
	       inc(buffptr[i]);
	       if (buffptr[i]=251) then buffptr[i]:=0;
	       dec(buffsize[i]);
	       cncycles[i]:=noteticks(cnote[i].leng)-notesilence(cnote[i].leng,musicKind[i]);
	       if ((i<7) or not(ryth)) then setnoteon(cnote[i].note,cnote[i].oct,i);
	       if ((i>6) and ryth) then
	       begin
		  if (cnote[i].note=1) then bass;
		  if (cnote[i].note=2) then tom;
		  if (cnote[i].note=3) then hihat;
		  if (cnote[i].note=4) then snare;
		  if (cnote[i].note=5) then cymbal;
	       end;
	    end;

	 if ((buffsize[i]=0) and (refill[i])) then refillbuffer(i);

	 {end loop!}
      end;
   end;
end;

{$F+}
procedure newexitproc;  
begin
   stop;
   exitproc:=exitsave;
   setintvec($1c,oldint1c);
   resetDevice;
   dispose(buff);
end;

procedure defaultrefill(ch : byte);
begin
 {do nothing}   
end; { defaultrefill }

{$F-}

procedure setMusicType(mk: word; c:byte);
begin
   if mk<6 then mk:=7;
   if mk>8 then mk:=7;
   musicKind[c]:=mk;
end; { setMusicType }

{install and ready the player, get memory ready and install the interrupt}
procedure init;
begin
   if inited then exit;
   if soundDevice=0 then exit;
   inited := true;
   new(buff);
   refillbuffer := defaultrefill;
   for i := 1 to 9 do
   begin
      cncycles[i] :=0;
      buffsize[i] :=0;
      buffptr[i] :=0;
      buffhead[i] :=0;
      musickind[i]:=normal;
      refill[i]:=false;
   end;
   
   getintvec($1C,oldint1c);
   setintvec($1c,@newint1c);

   exitsave:=exitproc;
   exitproc:=@newexitproc;
end;

function adlibDetected : boolean;
var
   d : boolean;
begin
   d := detectDevice;
   adlibDetected:=false;
   if d then
      begin
	 adlibDetected:=true;
	 soundDevice:=1;
         resetdevice;
         waveforms(true);
      end;
end;


begin
   inited:=false;
   playing:=false;
   soundDevice:=0;
   tempo:=120;   
end.
