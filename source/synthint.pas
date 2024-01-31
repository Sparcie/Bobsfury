{unit which provides a basic interface to the ad lib sound card}
{A Danson 2003}

unit synthint;

interface
uses fmsynth;
type
    instrument = record {see adlib docs for details!} {1 is operator 1 and 2 is operator 2}
		    mult1,mult2	: byte; {frequency multiplier and flags->  AM [7], vibrato [6],
					  sustain [5], envelope shortening[4], multiplier [3-0] }
		    keys1,keys2	: byte; {volume scaling and volume-> scaling level [7-6],
					   volume (0 is loudest 111111 is softest) [5-0] }
		    att1,att2	: byte; {attack/decay rate-> attack rate (0 slow F fast) [7-4],
  					   decay rate (same definition) [3-0] }
		    sust1,sust2	: byte; {sustain/release -> sustain level (0 low F high) [7-4],
					   release rate (same as attack/decay) [3-0]}
		    amd		: byte; {unused ... was going to be for Amplitude Modulation Depth
					/ Vibrato Depth / Rhythm}
		    feed	: byte; {feedback/modulation-> feedback (stength 0-7) [3-1],
					   modulation (0- op1 modulates op2, 1- both produce sound) [0]}
		    wave1,wave2	: byte; {waveform select [1-0] (see docs for waveforms)}
                 end;		


const
                              {           1  2   3  4   5    6   7   8   9   10  11  12}
                              {Notes   :- C# D   D#  E   F   F#  G   G#  A   A#  B   C }
      notemsb : array[1..12] of byte = ($01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02);
      notelsb : array[1..12] of byte = ($6b,$81,$98,$B0,$CA,$E5,$02,$20,$41,$63,$87,$AE);
      default1:instrument = (mult1: $01 ; mult2: $01 ; keys1: $CD;keys2: $0A;att1: $F0;att2: $F3;
                            sust1: $37; sust2: $37; amd: $00;feed: $00;wave1:$00;wave2:$00);
      default2:instrument = (mult1: $11 ; mult2: $01 ; keys1: $43;keys2: $85;att1: $F2;att2: $F4;
                            sust1: $14; sust2: $94; amd: $00;feed: $00;wave1:$02;wave2:$00);
      default3:instrument = (mult1: $01 ; mult2: $01 ; keys1: $0F;keys2: $00;att1: $A4;att2: $A4;
                            sust1: $02; sust2: $02; amd: $00;feed: $00;wave1:$00;wave2:$00);


procedure setnoteoff(channel:byte);
procedure setnoteon(note,oct,channel:byte);
function checkrange(i,min,max:byte):boolean;
procedure setchannel(i:instrument;ch:byte);
procedure setfmvol(vol,vol2:byte);
function getfmvol:byte;
procedure setmastervol(vol,vol2:byte);
function getmastervol:byte;
procedure initryth;
procedure hihat;
procedure cymbal;
procedure tom;
procedure bass;
procedure closeryth;
procedure snare;
procedure waveforms(wf : boolean);

procedure setdevice(aport : word);
function detectDevice:boolean;
procedure resetDevice;

implementation

const {BASS DRUM tom tom}
      drum1:instrument = (mult1: $00 ; mult2: $01 ; keys1: $00;keys2: $00;att1: $D6 ;att2: $A8;
                            sust1: $B5; sust2: $BC; amd: $00;feed: $00;wave1:$00;wave2:$00);
      {snare}
      drum2:instrument = (mult1: $00 ; mult2: $00 ; keys1: $80;keys2: $80;att1: $A6;att2: $A6;
                            sust1: $08; sust2: $08; amd: $00;feed: $00;wave1:$02;wave2:$02);
      {cymbal hihat }
      drum3:instrument = (mult1: $00 ; mult2: $00 ; keys1: $80;keys2: $80;att1: $A6;att2: $A6;
                            sust1: $06; sust2: $04; amd: $00;feed: $00;wave1:$02;wave2:$02);

var
   rhyt	  : boolean;
   nsave  : array[0..8] of byte;
   device : word;

function checkrange(i,min,max:byte):boolean;
begin
   checkrange:=true;
   if i<min then checkrange:=false;
   if i>max then checkrange:=false;
end;

procedure waveforms(wf : boolean);
begin
   setWaveFormControl(device,wf);
end;

procedure setnoteon(note,oct,channel:byte);
var dat,reg:byte;
begin
   if ((checkrange(note,1,12) and checkrange(oct,0,7)) and checkrange(channel,1,9)) then
   begin
      channel:=channel-1;
      reg:=$A0 + channel;
      writetosb(device,reg,notelsb[note]);
      dat:=notemsb[note];
      reg:=$B0 + channel;
      dat:= dat or (oct shl 2);
      nsave[channel]:=dat;
      dat:=dat or bits[5];
      writetosb(device,reg,dat);
   end;
end;

procedure setnoteoff(channel:byte);
var reg:byte;
begin
   if checkrange(channel,1,9) then
   begin
      channel:=channel-1;
      reg:=$B0 + channel;
      writetosb(device,reg, nsave[channel]);
   end;
end;

procedure setchannel(i:instrument;ch:byte);
var reg,dat,chb:byte;
begin
   if not(checkrange(ch,1,9)) then Exit;
   with i do
   begin
      chb:=ch-1;
      reg:=$20 + op1[ch];
      writetosb(device,reg,mult1);
      reg:=$20 + op2[ch];
      writetosb(device,reg,mult2);
      reg:=$60 + op1[ch];
      writetosb(device,reg,att1);
      reg:=$60 + op2[ch];
      writetosb(device,reg,att2);
      reg:=$80 + op1[ch];
      writetosb(device,reg,sust1);
      reg:=$80 + op2[ch];
      writetosb(device,reg,sust2);
      {sendboths($BD,amd); modifies all channels!!!}
      reg:=$C0 + chb;
      writetosb(device,reg,feed);
      reg:=$E0 + op1[ch];
      writetosb(device,reg,wave1);
      reg:=$E0 + op2[ch];
      writetosb(device,reg,wave2);
      reg:=$40 + op1[ch];
      writetosb(device,reg,keys1);
      reg:=$40 + op2[ch];
      writetosb(device,reg,keys2);
   end;
end;

procedure setfmvol(vol,vol2:byte);
begin
   if not(checkrange(vol,0,15) and checkrange(vol2,0,15)) then Exit;
   vol:=vol or ((vol2 shl 4) and $f0);
   Port[$224]:=$26;
   port[$225]:=vol;
end;

function getfmvol:byte;
var vol,d:byte;
begin
   port[$224]:=$26;
   vol:=port[$225];
   d:=vol shr 4 ;
   vol:=vol and $0F;
   if vol>d then d:=vol;
   getfmvol:= d;
end;

procedure setmastervol(vol,vol2:byte);
begin
   if not(checkrange(vol,0,15) and checkrange(vol2,0,15)) then Exit;
   vol:=vol or ((vol2 shl 4) and $f0);
   Port[$224]:=$22;
   port[$225]:=vol;
end;

function getmastervol:byte;
var vol,d:byte;
begin
   port[$224]:=$22;
   vol:=port[$225];
   d:=vol shr 4 ;
   vol:=vol and $0F;
   if vol>d then d:=vol;
   getmastervol:= d;
end;

{
***************rythm section***************
}
{   rhyt,bass,snare,tom,cymbal,hihat:boolean;}

procedure setryth(func :byte);
var dat : byte;
begin
   dat:=$00;
   if rhyt then dat:=bits[5];
   if (checkrange(func,0,4)) then dat:= dat or bits[func];

   {  if bass then dat:=dat or bits[4];
   if snare then dat:=dat or bits[3];
   if tom then dat:=dat or bits[2];
   if cymbal then dat:=dat or bits[1];
   if hihat then dat:=dat or bits[0];}
   writetosb(device,$BD,dat);
end;

procedure setrythnote(note,oct,channel:byte);
var dat,reg:byte;
begin
   if ((checkrange(note,1,12) and checkrange(oct,0,7)) and checkrange(channel,1,9)) then
   begin
      channel:=channel-1;
      reg:=$A0 + channel;
      writetosb(device,reg,notelsb[note]);
      dat:=notemsb[note];
      reg:=$B0 + channel;
      dat:=dat + (oct * 4);
      writetosb(device,reg,dat);
   end;
end;

procedure initryth;
begin
   setrythnote(1,0,7);
   setrythnote(8,4,9);
   setrythnote(1,6,8);
   setchannel(drum1,7);
   setchannel(drum2,8);
   setchannel(drum3,9);
   rhyt:=true;
   waveforms(true);
   setryth(5);
end;

procedure bass;
begin
   setryth(4);
end;

procedure snare;
begin
   setryth(3);  
end;

procedure tom;
begin
   setryth(2);
end;

procedure cymbal;
begin
   setryth(1);
end;

procedure hihat;
begin
   setryth(0);
end;

procedure closeryth;
begin
   setchannel(default1,7);
   setchannel(default1,8);
   setchannel(default1,9);
   rhyt:=false;
   setryth(6);
end;

procedure setdevice(aport : word);
begin
   device:=aport;
end;

function detectDevice:boolean;
begin
   detectDevice := detect(device);
end;

procedure resetDevice;
begin
   reset(device);
end;

begin
   device := adlib;
end.
