unit music;                                                      { version 1.0 }


(******************************************************** 1990 J.C. Kessels ****
Play music in the background.


This unit gives you music capabilities with a BASIC syntax. The music
will be played in the background, so your program can continue with
other things. The music can also be played in the foreground.

This unit is very easy to use. There are only three procedures and one
function interfaced outwards. All the rest is automatic (installing,
uninstalling, interpreting the music, etc.)!

 Modified 2017 by A Danson for using a faster PIT rate (36.4hz)


PlayMusic(string);
          Start playing a string of music in the background. The string
          is a normal character string containing music 'commands' as
          described below. If there is already music playing, then it is
          first shut off. All settings are reset to their default.

PlayMusicForeground(string);
          Start playing a string of music, and wait for it to finish. If
          there is already music playing, then it is first shut off. All
          settings are reset to their default.
          This procedure simply calls the "PlayMusic" procedure, and then
          loops until MusicBusy (described later) is true.

MusicOff;
          Turn music off.

if MusicBusy then ...
          Return TRUE if there is currently music playing.

See at the end of this unit for a small demonstration program.





The music-commands syntax is (BASIC compatible):

[>,<]A..G[#,+,-](n)[.]
          Play note A..G in the current octave. There are 12 notes per
          octave: C, C#, D, D#, E, F, F#, G, G#, A, A#, B.
           If the note is prefixed by '>', then it is transposed one octave
            upwards.
           If the note is prefixed by '<', then it is transposed one octave
            downward.
           if the note is followed by '#' or '+', then the note is made
            "sharp" (one note up, 'D' becomes 'D#', 'E' becomes 'F').
           If the note is followed by '-', then the note is made "flat" (one
            note down, 'D' becomes 'C#').
           If the note is followed by a number, then the number specifies the
            length of this note, overriding the default notelength set by 'L'.
           Every period following the notenumber will increase the playtime
            by 3/2.
          Example:   >B+3.
                     >      : transposed
                      B     : note B
                       +    : sharp
                        3   : length 3
                         .  : 3/2 longer
N(n)[.]   Play note "n", in which "n" is a number 0..84. There are 7 octaves,
          12 notes per octave. Note 0 means: silence. The first note in the
          first octave is 'N1'.
           Every period following the notenumber will increase the playtime
            by 3/2.
O(n)      Sets the octave to "n", in which "n" is a number 0..7. Each octave
          goes from note 'C' to 'B'. Octave 3 starts with middle 'C'. Default
          octave is 4.
L(n)      Set the default length of following notes to "n", in which "n" is
          a number 1..64. L1 = whole notes, L2 = half notes, L4 = quarter
          notes, etc. Default length is 4. In one minute fit 120 quarter
          notes ('L4'), adjustable with the 'T' (tempo) command.
T(n)      Set the tempo to "n", in which "n" is a number 32..255. The tempo
          is the number of quarter notes ('L4') that are played per minute.
          The higher the tempo, the faster the music. Default tempo is 120.
MN        Music Normal. Every note plays seven-eights of the time set by
          'L', and is followed by a pause of one-eight. Thus, every note is
          followed by a small silence, making the music more natural.
ML        Music Legato. Every note plays the full time set by 'L'. Thus, every
          note is immediately followed by the next note, making the music a
          bit synthetic.
MS        Music Staccato. Every note plays three-quarters of the time
          set by 'L', and is followed by a pause of one-quarter. Thus, every
          note is followed by a clearly audible silence, making the music
          very rithmic.
P(n)[.]   Insert a pause with a length of "n", in which "n" is a number
          1..64.
           Every period following the number will increase the playtime
            by 3/2.

Not supported (ignored):
MF        Foreground: Cannot switch between foreground/background.
MB        Background: Cannot switch between foreground/background.
Xs$;      Include string: Cannot include substrings.
=n;       Use variable "n": Cannot replace variable's names by their contents.

Spaces are allowed between commands, but not inside commands.
Upper/lowercase is not important.




THEORY.

This unit installs itself in the timertick interrupt $1C (procedure
"MusicNext"). With every timertick a buffer is checked. If there is any
music to be played in the buffer, then a single note from the buffer is
played.




This unit was inspired by a (buggy and incomplete) public domain unit
written by Michael Quinlan, 9/17/85.



J.C. Kessels
Philips de Goedelaan 7
5615 PN Eindhoven
Netherlands
*******************************************************************************)




Interface


procedure MusicOff;
procedure PlayMusic(s : string);
procedure PlayMusicForeground(s : string);
function MusicBusy : boolean;

Implementation
uses dos, pitdbl;

var
  OldInt1C        : pointer;               { Pointer to old interrupt routine. }
  ExitSave        : pointer;             { Pointer to previous exit procedure. }
  MusicString     : string;                         { The string to be played. }
  MusicHere       : word;  { Pointer into MusicString, non-zero while playing. }
  MusicDelay1     : word;             { Clockticks countdown for current note. }
  MusicDelay2     : word;             { Clockticks countdown for current note. }
  MusicNoteLength : word;                               { Current note length. }
  MusicTempo      : word;                                     { Current tempo. }
  MusicOctave     : word;                                    { Current octave. }
  MusicKind       : word;              { 8 = Legato, 7 = Normal, 6 = Staccato. }
  { Array with coded frequencies: 12 notes per octave (C, C#, D, D#, E, F, F#,
    G, G#, A, A#, B), 7 octaves. }
  Frequency       : array[0..83] of word;
   inited         : boolean;

   procedure Initialize; forward;

function GetNumber(min, max, default : word) : word;
{ Get a number from the MusicString, starting at MusicHere. Increment MusicHere
  past the end of the number. If the number is <min or >max then the default
  number is returned. This routine will also skip the Basic syntax for a
  variable: '=name;' }
var
  n : word;
begin
{ Ignore Basic syntax for embedded variable instead of constant, and exit with
  the default. }
if (MusicHere <= length(MusicString)) and (MusicString[MusicHere] = '=') then
  begin
  while (MusicHere <= length(MusicString)) and (MusicString[MusicHere] <> ';')
    do inc(MusicHere);
  if (MusicHere <= length(MusicString)) and (MusicString[MusicHere] = ';')
    then inc(MusicHere);
  GetNumber := default;
  exit;
  end;

{ Accept a number from the MusicString. The number is finished by anything that
  is not a number '0'..'9'. }
n := 0;
while (MusicHere <= length(MusicString)) and
  (MusicString[MusicHere] in ['0'..'9']) do
  begin
  n := n * 10 + (Ord(MusicString[MusicHere]) - Ord('0'));
  inc(MusicHere);
  end;

{ Test if the number is within range, otherwise return the default. }
if (n < min) or (n > max)
  then GetNumber := default
  else GetNumber := n;
end;


function localRound(r : real):integer;
begin
   localround:=0;
   if r>maxint then exit;
   if r<-32767 then exit;
   localRound:=trunc(r);
   if (frac(r)>0.5) then localRound := trunc(r)+1;
end;


procedure SetupDelays;
{ Setup MusicDelay1 and MusicDelay2. The first determines the time that a note
  is audible, the second determines a rest between two notes (Legato, Normal,
  Staccato). To do this, accept a note-length number from the MusicString, or
  use the default NoteLength. Also accept trailing dot's from the MusicString,
  which lengthen the note-length by 1.5. }
var
  r,t : real;
   
begin
r := GetNumber(1,128,MusicNoteLength);                         { Accept number.}
{ Note: the number is reciprocal. A high number means a short note. If the
  number is 4, then it is a 'normal' note. Think of the number as: "the number
  of quarter notes that the note will last". }

while (MusicHere <= length(MusicString)) and          { Accept trailing dot's. }
   (MusicString[MusicHere] = '.') do
  begin
  inc(MusicHere);
  r := r * 0.75;             { Every dot increases the note time by 1.5 times. }
  end;

{ Translate into clocktick delays. The following formula is used:
  There are 120 'standard' notes per minute.
        ticks = ThisNoteLength * ThisTempo * TicksPerStandardNote
        ThisNoteLength = 4 / NoteLength
        ThisTempo = 120 / MusicTempo
        TicksPerStandardNote = TicksPerMinute / 120
        TicksPerMinute = TicksPerSecond * 60
        TicksPerSecond = 18.2
  ticks := 4 * 18.2 * 60 * / (NoteLength * MusicTempo)
  modified for the faster PIT
  }
r:= r * MusicTempo;
t:= 4368 * pitRatio;

if (r>t) then MusicDelay1:=1 else   
   MusicDelay1 := localRound(t / r);

{ The clockticks are split two ways: every note is followed by a small amount
  of silence (Legato, Normal, Staccato). MusicDelay1 determines the 'on' time,
  MusicDelay2 determines the 'off' time. }
if MusicKind < 8
  then MusicDelay2 := MusicDelay1 * (8 - MusicKind) div 8
  else MusicDelay2 := 0;
dec(MusicDelay1,MusicDelay2);
end;




procedure MusicNext; interrupt;
{ Play the MusicString. This procedure is installed into the timer interrupt,
  and therefore runs with every timer-tick. The routine takes music from the
  MusicString, from position MusicHere. If MusicHere is zero, then the music is
  disabled. The duration of a note is determined by MusicDelay1 and
  MusicDelay2, both set by the SetupDelays procedure. }
var
  note : word;                                          { Temporary variables. }
  ch : char;
begin
{ Call the old timer handler. The address of the old handler is saved by the
  installation code at the end of the unit. }
Inline(
  $9C/                   {pushf}
  $FF/$1E/>OLDINT1C);    {call far [>OldInt1C]}

{ Decrement MusicDelay1. This determines the time that a note is 'on'. }
if MusicDelay1 > 0 then
  begin
  dec(MusicDelay1);                                         { Decrement delay. }
  if MusicDelay1 > 0 then exit;                      { Exit if delay not zero. }
  end;

{ If there is a second delay, then move it to the main delay counter and exit.
  The second delay time determines a silence after each note (Legato, Normal,
  Staccato). }
if MusicDelay2 > 0 then
  begin
  MusicDelay1 := MusicDelay2;            { Move second delay into first delay. }
  MusicDelay2 := 0;
  Port[$61] := Port[$61] and $78;                                 { Sound off. }
  exit;                                                                { Exit. }
  end;

{ If MusicString all done then sound off and exit. }
if MusicHere = 0 then exit;
if MusicHere > length(MusicString) then
  begin
  MusicHere := 0;
  Port[$61] := Port[$61] and $78;                                 { Sound off. }
  exit;                                                                { Exit. }
  end;

{ Process commands from MusicString, until a note or a pause can be played. A
  few Basic commands are not supported, these are ignored. }
while MusicHere <= length(MusicString) do
  begin
  ch := upcase(MusicString[MusicHere]);      { Get character from MusicString. }
  inc(MusicHere);
  case ch of
    'O' : MusicOctave := GetNumber(0,7,4);                       { Set octave. }
    'L' : MusicNoteLength := GetNumber(1,128,4);             { Set note length.}
    'T' : MusicTempo := Getnumber(32,255,120);                    { Set tempo. }
    'M' : if MusicHere <= length(MusicString) then             { 'M' commands. }
          begin
          ch := upcase(MusicString[MusicHere]);
          inc(MusicHere);
          case ch of
            'L' : MusicKind := 8;                                { Set legato. }
            'N' : MusicKind := 7;                                { Set normal. }
            'S' : MusicKind := 6;                              { Set staccato. }
            end;
          end;
    'P' : begin                                                       { Pause. }
          Port[$61] := Port[$61] and $F8;
          SetupDelays;
          exit;
          end;
    'A'..'G','>','<' : begin                                    { Play a note. }
          note := MusicOctave * 12;
          if ch = '>' then
            begin                                                { Accept '>'. }
            if MusicHere <= length(MusicString) then
              ch := upcase(MusicString[MusicHere]);
            inc(MusicHere);
            if note <= 71 then inc(note,12);
            end;
          if ch = '<' then
            begin                                                { Accept '<'. }
            if MusicHere <= length(MusicString) then
              ch := upcase(MusicString[MusicHere]);
            inc(MusicHere);
            if note >= 12 then dec(note,12);
            end;
          case ch of                            { Determine frequency of note. }
            'A' : inc(note,9);
            'B' : inc(note,11);
            'C' : inc(note,0);
            'D' : inc(note,2);
            'E' : inc(note,4);
            'F' : inc(note,5);
            'G' : inc(note,7);
            end;
          { Accept '#' or '+' following the letter. }
          if (MusicHere <= length(MusicString)) and
             ( (MusicString[MusicHere] = '#') or (MusicString[MusicHere] = '+') )
             then
            begin
            inc(MusicHere);
            if note < 83 then inc(note);
            end;
          { Accept '-' following the letter. }
          if (MusicHere <= length(MusicString)) and
             (MusicString[MusicHere] = '-') then
            begin
            inc(MusicHere);
            if note > 0 then dec(note);
            end;
          note := Frequency[note];          { Translate note into 'frequency'. }
          Port[$61] := Port[$61] and $78;                         { Sound off. }
          Port[$43] := $B6;                                { Setup timer chip. }
          Port[$42] := Lo(note);                            { Setup frequency. }
          Port[$42] := Hi(note);
          Port[$61] := (Port[$61] and $7F) or $03;                           { Sound on. }
          SetupDelays;                             { Setup note length delays. }
          exit;
          end;
    'N' : begin                                        { Play a specific note. }
          note := GetNumber(1,84,0);                     { Accept note number. }
          Port[$61] := Port[$61] and $78;                         { Sound off. }
          if note > 0 then                               { Zero means silence. }
            begin
            note := Frequency[note-1];      { Translate note into 'frequency'. }
            Port[$43] := $B6;                              { Setup timer chip. }
            Port[$42] := Lo(note);                          { Setup frequency. }
            Port[$42] := Hi(note);
            Port[$61] := (Port[$61] and $7f) or $03;                         { Sound on. }
            end;
          SetupDelays;                             { Setup note length delays. }
          exit;
          end;
    'X' : begin                { Skip the Basic syntax for an embedded string. }
          while (MusicHere <= length(MusicString)) and
            (MusicString[MusicHere] <> ';') do inc(MusicHere);
          if (MusicHere <= length(MusicString)) and
            (MusicString[MusicHere] = ';') then inc(MusicHere);
          end;
    end;
  end;
end;



procedure MusicOff;
{ Turn music off. }
begin
   if not(inited) then exit;
MusicHere := 0;                                               { Index is zero. }
MusicDelay1 := 0;                                             { Delay is zero. }
MusicDelay2 := 0;                                             { Delay is zero. }
Port[$61] := Port[$61] and $F8;                                   { Sound off. }
end;




procedure PlayMusic(s : string);
{ Start playing a string of music in the background. If there is already music
  playing, then first shut it off. All settings revert to their default. }
begin
   if not(inited) then Initialize;
MusicOff;                                              { Shutup current music. }
MusicString := s;                              { Save string into MusicString. }
MusicNoteLength := 4;                                        { Setup defaults. }
MusicTempo := 120;
MusicOctave := 4;
MusicKind := 7;
MusicHere := 1;                            { Start music (at begin of string). }
end;




procedure PlayMusicForeground(s : string);
{ Start playing a string of music, and wait for it to finish. If there is
  already music playing, then first shut it off. All settings revert to their
  default. }
begin
PlayMusic(s);
while MusicHere > 0 do ;
end;




function MusicBusy : boolean;
{ If there is music playing then return TRUE. }
begin
if MusicHere > 0
  then MusicBusy := true
  else MusicBusy := false;
end;




{$F+}                                                  { Must be compiled FAR. }
procedure ShutDown;
{ Un-install the unit, and turn music off. It is absolutely necessary that the
  MusicNext procedure is un-installed from the timertick interrupt, or the
  system may crash. }
begin
MusicOff;                                                         { Music off. }
ExitProc := ExitSave;                          { Reinstall old exit procedure. }
SetIntVec($1C,OldInt1C);                      { Install old interrupt handler. }
end;
{$F-}




procedure Initialize;
var
  i : word;
  r1, r2 : real;
begin
   if inited then exit;
   inited:=true;
{ Fill the frequency array with words that can be fed into the timer chip. The
  array contains coded frequencies, one for every note (0..11) in every octave
  (0..6). The first note of an octave is exactly 2 times as high as the first
  note in the first-lower octave. This means that the distance between two
  notes is exactly 12û2 = exp(ln(2)/12). Starting at a 'base' frequency for the
  highest note in the highest octave, we can calculate all the notes in all the
  octaves. The timer chip expects a reciprocal number (1193180 / frequency). }
r1 := 1193180.0 / 8000.0;                           { Highest note is 8000 Hz. }
r2 := exp(ln(2.0)/12.0);                           { Distance between 2 notes. }
for i := 83 downto 0 do                                { Fill frequency array. }
  begin
  Frequency[i] := round(r1);
  r1 := r1 * r2;
  end;

MusicOff;                                              { Initialize variables. }
GetIntVec($1C,OldInt1C);            { Save address of previous int-1C handler. }
SetIntVec($1C,@MusicNext);                    { Install our interrupt handler. }
ExitSave := ExitProc;               { Save address of previous exit procedure. }
ExitProc := @ShutDown;                           { Install ShutDown procedure. }
end;




{ Initialization code. }
begin
   inited:=false;
end.






(***************************** Example program *********************************
program test;
uses music;


begin
{ Anthem }
PlayMusic('T100O3L8E-.L16CO2L4A-O3L4CE-L2A-O4L8C.O3L16B-L4A-CDL2E-L8E-E-O4L4C.'+
  'O3L8B-L4A-L2GL8FGL4A-A-E-CO2L4A-O4L8CCL4CD-E-L2E-L8D-CO3L4B-O4L4CD-L2D-L8D-'+
  'D-L4C.O3L8B-L4A-L2GL8FL16G.L4A-CDL2E-L8E-E-L4A-A-L8A-GL4FFFB-O4L8D-CO3L8B-'+
  'A-L4A-L4G.P8L8E-E-O3L4A-.L8B-O4L8CD-L2E-O3L8A-B-O4L4C.L8D-O3L4B-L2A-..');
while MusicBusy do write('Playing the Anthem....');

{ Anvil }
PlayMusic('T200O3E2E4.E8E4.D8C4.O2A8G4.B8O3D4.F8E2C2E2E4.E8E4.D8C4.O2A8G4.B8'+
  'O3D4.F8E4C4E2C4P4D4P4O2B4O3C4O2A4B4E4P4P8G+8A8B8O3C4C4P8O2B8O3C8D8E4E4P8D8'+
  'E8F8G2.F8G16F16E4P4P2');
while MusicBusy do write('Playing Anvil....');

{ Bouree }
PlayMusic('MBMLL8T150O4DEF4EDC+4DEO3A4BO4C+DP10CO3B-A4GFE4FGAP16GF16E16D8P10'+
  'O4DEF4EDA4FAO3A4BO4C+DP10CO3B-A4GFP32F16G16F16E16F16.P32F2');
while MusicBusy do write('Playing Bouree....');

writeln('Music is done.');
end.
*******************************************************************************)
