{ unit for storing and playing our own music files }
{ A Danson 2005}

unit BMusic;

interface
uses FMplayer,synthint; {used for their record structures}

{methods for ordinary music play back!}
procedure play;
procedure stop;
procedure load(fle:string);
procedure save(fle:string);
procedure wait; {waits until song is finished}
function isplaying:boolean;
procedure setRepeat(r:boolean);

{methods for Bobsfury }
{load a music list by reading a specific path}
procedure loadList(path:string);
{change song * blocks until current song has emptied its buffers}
{songs will automatically change when they end.(if a list is loaded)}
procedure changesong;
{because we can't read the hard disk during an interrupt
 we cannot change the song automatically within the interrupt.
 call this function to check if the song needs to have the next one
 loaded}
procedure checkSongChange;


{methods for editing the current song in memory}
{cursor control}
procedure newFile(ch:byte); {creates a new song with some empty data channels}

function next:boolean; {next and previous cursor movements}
function prev:boolean;
   function moveto(index : integer):boolean; {move cursor to the note at the indexed location) }
function notecount:integer;        {count the notes in this channel}

function channelCount: byte;
{set the current channel (resets the cursor to start)}
procedure channel(ch:byte);
procedure setInstrument(inst:instrument);
{get Note}
procedure getNote(var n:Note);
procedure setNote(n:Note);
procedure insert;{inserts a blank note}
procedure remove;{removes the note}

implementation

uses dos;

{the structure for a channel }
type block = record
        notes: array[1..100] of note;
        next,prev: pointer;
        used:byte;
        tail:boolean;
        end;
     blockptr = ^block;

var
   exitsave:pointer;
   nchan,nsongs,csong:integer; {number of channels and songs and current song}
   channels: array[1..5] of blockptr; {the root blocks for each channel}
   channelpos: array[1..5] of integer; 
   cchptr: array[1..5] of blockptr;
    {block in which this channel is at in playback -1 indicates finished}
   instruments: array[1..5] of instrument; {the instruments for each channel}
   playing,loaded,dorepeat:boolean;

var {list of songs data}
   songPath:string;   
   songs:array[1..60] of string[22];

var {editor cursor}
   ech,epos:integer;
   eblk:blockptr;
   { load next song in list when asked? }

const
    firstch=3;

{creates a new block that is pre initialized}
function newBlock:blockptr;
var n : blockptr;
begin
   new(n);
   n^.used:=0;
   n^.tail:=false;
   n^.next:=nil;
   n^.prev:=nil;
   newBlock:=n;
end;

{error method}
procedure error(err:string);
begin
   write('Music error: ');
   writeln(err);
   halt(1);
end;

{free memory from a loaded piece of music}
procedure unload;
var n,t:blockptr;
    i:integer;
begin
   stop;
   if not(loaded) then exit;
   loaded:=false;
   for i:=1 to nchan do
   begin
      n := channels[i];
      channels[i]:=nil;
      while not(n^.tail) do
      begin
	 t:=n^.next;
	 dispose(n);
	 n:=t;    
      end;
      dispose(n);
   end;
end;

{****************************
 methods related to playing
 ****************************}

procedure sendBlock(bck:blockptr;ch:byte);
var i:integer;
begin
 for i:= 1 to bck^.used do
 begin
    addnoteRecord( bck^.notes[i], ch+firstch);
 end;
end;

procedure checkend;
var c,sc:integer;    
begin
   sc:=0;
   for c:=1 to nchan do
    begin
        if ((channelpos[c]=-1) and (buffersize(c+firstch)=0)) then inc(sc);
    end;
   if (sc=nchan) then
    begin
       playing:=false;
    end;
end;

{$f+}
procedure refill(ch:byte);
begin
    if not(loaded) then exit;
    {check if we should be playing}
    ch:=ch-firstch;
    if (channelpos[ch]=-1) then
    begin
       checkend;
       exit;
    end;
    if not(playing) then exit;
    if (ch>nchan) then exit;
    inc(channelpos[ch]);
    cchptr[ch] := cchptr[ch]^.next;
    if ((cchptr[ch]^.tail) or (cchptr[ch]^.next=nil)) then
    begin {here we should check for repetition flag}
        if (dorepeat) then
        begin
            channelpos[ch]:=0;
            cchptr[ch] := channels[ch];
        end
        else
        begin
            channelpos[ch]:=-1;
            checkend;           
        end;
    end;
    sendblock(cchptr[ch],ch);
end;
{$f-}

{methods for ordinary music play back!}
procedure play;
var c:integer; 
begin
    if not(loaded) then exit;
    if playing then exit;
    for c:=1 to nchan do
    begin
        refillalarm(c+firstch,false);
        channelpos[c]:=0;
        cchptr[c] := channels[c];
        fmplayer.setinstrument(instruments[c],c+firstch);
        sendblock(cchptr[c],c);
        refillalarm(c+firstch,true);
    end;
    playing:=true;
end;

procedure stop;
var c:integer;
begin
    if not(loaded) then exit;
    if not(playing) then exit;
    for c:=1 to nchan do
    begin
       refillalarm(c+firstch,false);
       clearchannel(c+firstch);
    end;
    playing:=false;
end;

procedure load(fle:string);
var fin: file;
    count,i,c : word;
    current,next : blockptr;
    t :boolean;
begin
   unload;
   assign(fin,fle);
   reset(fin,1);
   blockread(fin,instruments,5*sizeof(instrument),count);
   if not(count=5*sizeof(instrument)) then error('instrument read error');
   blockread(fin,nchan,sizeof(integer),count);
   if not(count=sizeof(integer)) then error('nchan read error');
   {read the tempo (set it) and the music kind for each channel}
   blockread(fin,i,sizeof(word),count);
   if not(count=sizeof(word)) then error('tempo read error');
   fmplayer.setTempo(i);
   for i:=1 to nchan do
   begin
      blockread(fin,c,sizeof(word),count);
      if not(count=sizeof(word)) then error('Musickind read error');
      setMusictype(c,i+firstch);
   end;
   {begin reading the channel data using the tail flag to determine the end.}
   for i:=1 to nchan do
   begin
      t:=false;
      {create the memory for the root block}
      channels[i] := newBlock;
      current:= channels[i];
      current^.prev := nil;
      {there is allways at least one block}
      blockread(fin,current^,sizeof(block),count);
      if not(count=sizeof(block)) then error('root block read');
      t:= current^.tail;
      next:=current;
      while not(t) do
      begin
	 {create a new space}
	 next:=newBlock;
	 current^.next := next;
	 blockread(fin,next^,sizeof(block),count);
	 if not(count=sizeof(block)) then error('block read');
	 next^.prev := current;
	 current := next;
	 t:= next^.tail;
      end;
   end;
   close(fin);   
   loaded:=true;
end;

procedure movenotes(src,dest : blockptr; amount:word);
var i : word;
    
begin
   {copy source to destination}
   for i:=1 to amount do
   begin
      dest^.notes[dest^.used+i] := src^.notes[i];
   end;
   dest^.used:=dest^.used+amount;

   src^.used:=src^.used-amount;
   for i:= 1 to src^.used do
   begin
      src^.notes[i] := src^.notes[i+amount];
   end;
end;

procedure compact;
var
   ch		     : word;
   current,next,temp : blockptr;
   take		     : word;
   moved	     : word;
begin
   moved:=0;
   for ch:= 1 to nchan do
   begin
      current:=channels[ch];
      while not(current^.tail) do
      begin
	 next:=current^.next;
	 if current^.used=0 then
	 begin {remove this block}
	    if not(current^.tail) then
	    begin
	       next^.prev := current^.prev;
	       temp:=current^.prev;
	       temp^.next:=next;
	       dispose(current);
	       next:=current^.next;
	    end;
	    if ((current^.tail) and not(current^.prev=nil)) then
	    begin
	       temp:=current^.prev;
	       temp^.tail:=true;
	       temp^.next:=nil;
	       next:=temp;
	       dispose(current);
	    end;      
	 end
	 else
	    if ((current^.used<100) and not(next=nil) and not(current^.tail) ) then
	    begin {if there is a next and we aren't full take what we can!}
	       take:= 100-current^.used;
	       if take>next^.used then take:=next^.used;
	       if take>0 then moveNotes(next,current,take);
	       moved:=moved+take;
	    end;
	 current := next;
      end;      
   end;
   if moved>0 then compact;
end;

procedure save(fle:string);
var out:file;
    count,i,c:word;
    current:blockptr;
    t:boolean;
begin
    if not(loaded) then exit;
    compact;
    assign(out,fle);
    rewrite(out,1);  
    blockwrite(out,instruments,5*sizeof(instrument),count);
    if not(count=5*sizeof(instrument)) then error('instrument write out error');
    blockwrite(out,nchan,sizeof(integer),count);
    if not(count=sizeof(integer)) then error('nchan write out error');
    {write settings such as tempo and music type}
    i:= getTempo;
    blockwrite(out,i,sizeof(word),count);
    if not(count=sizeof(word)) then error('Tempo write out error');
    for i:= 1 to nchan do
    begin
       c:=getMusicKind(i+firstch);
       blockwrite(out,c,sizeof(word),count);
       if not(count=sizeof(word)) then error('musicKind write out error');
    end;      
    {write out each channel util the block with tail set to true is reached}
    for i:=1 to nchan do
    begin
        current := channels[i];
        t:=false;
        while not(t) do
        begin
            t:=current^.tail;
            blockwrite(out,current^,sizeof(block),count);
            if not(count=sizeof(block)) then error('block write error');
            current := current^.next;
        end;
    end;     
    close(out);
end;

procedure wait; {waits until song is finished entering a buffer}
begin
    while (playing) do checkend;
end;

function isplaying:boolean;
begin
   checkend;
   isplaying:=playing;
end;

procedure setRepeat(r:boolean);
begin
 dorepeat:=r;
end;

{*******************
methods for Bobsfury
********************* }
{load a music list (reads a path for a list of music)}
procedure loadList(path:string);
var cf :searchrec;
begin
    nsongs:=0;
    csong:=0;
    findfirst(path+'*.bfm',anyfile,cf);
    while doserror=0 do
    begin
        inc(nsongs);
        songs[nsongs] := path + cf.name;
        findnext(cf);
    end;
    csong:=0;
end;

{change song * blocks until current song has emptied its buffers}
{songs will automatically change when they end.(if a list is loaded)}
procedure changesong;
begin
    if nsongs=0 then exit; {check if there are songs in the list}
    if (csong=nsongs) then csong:=0; {repeat the songs}
    dorepeat:=false; {so this does not block forever}
    wait; {wait until current song is finished}
    fmplayer.stop;
    inc(csong);
    load(songs[csong]);
    fmplayer.start;
    play;
end; { changesong }

{because we can't read the hard disk during an interrupt (dos crashes!)
 we cannot change the song automatically within the interrupt.
 call this function to check if the song needs to have the next one
 loaded}
procedure checkSongChange;
begin
   if not(loaded) then exit;
   if not(playing) then changesong;
end;

{methods for editing the current song in memory (only available if not playing)}
{cursor control}
procedure newFile(ch:byte); {creates a new song with some empty data channels}
var i:integer;
begin
    unload; {just in case we allready have a file in memory}
    nchan := ch;
    if (nchan>5) then error('Cant have that many channels!');
    for i:= 1 to nchan do
    begin
        channels[i]:= newBlock;
        channels[i]^.tail:=true;
        channels[i]^.prev:=nil;
        channels[i]^.next:=nil;
        channels[i]^.used:=0;
    end;
    loaded:=true; {loaded true but no music in the file!}
end;

function next:boolean; {next and previous cursor movements}
begin
    next:=true;
    if (not(loaded) or (ech=-1)) then exit;
    inc(epos);
    if (epos-1 = eblk^.used) then
        if not(eblk^.tail) then
        begin
            epos:=1;
            eblk := eblk^.next;
        end
        else
        begin
            dec(epos);
            next:=false;
        end;
end;

function prev:boolean;
begin
    prev:=true;
    if (not(loaded) or (ech=-1)) then exit;
    dec(epos);
    if (epos = 0) then
        if not(eblk^.prev = nil) then
        begin
            eblk := eblk^.prev;
            epos := eblk^.used;
        end
        else
        begin
            inc(epos);
            prev:=false;
        end;
end;

function moveto(index : integer): boolean; {move cursor to the note at the indexed location) }
var
   i : integer;
   z : boolean;
begin
   eblk := channels[ech];
   epos := 1;
   for i:= 1 to index do z:=next;
end;

function notecount:integer;        {count the notes in this channel}
var
   count   : integer;
   current : blockptr;
   done	   : boolean;
begin
   current := channels[ech];
   done := false;
   count := 0;

   while not(done) do
      begin
	 count := count + current^.used;
	 if not(current^.tail) then
	    current := current^.next
	 else
	    done := true;
      end;
   notecount := count;
end;

{gets the channel count}
function channelCount:byte;
begin
   channelCount := nchan;
end;

{set the current channel (resets the cursor to start)}
procedure channel(ch:byte);
begin
    if (not(loaded)) then exit;
    if (ch<1) then exit;
    if (ch>nchan) then exit;
    eblk := channels[ch];
    ech := ch;
    epos:= 1;
end;

{get Note}
procedure getNote(var n:Note);
begin
    if (not(loaded) or (ech=-1)) then exit;
    if ((epos<1) or (epos>100)) then exit;
    n:= eblk^.notes[epos];
end;

procedure setNote(n:Note);
begin
    if (not(loaded) or (ech=-1)) then exit;
    if ((epos<1) or (epos>100)) then exit;
    eblk^.notes[epos]:=n;
end;

procedure split; {splits a block into two and does appropriate memory stuff}
var nw,n:blockptr;
    i:integer;
begin
    {create the new block}
    nw:=newBlock;
    nw^.used:=0;
    n:= eblk^.next;  
    eblk^.next:=nw;
    if not(eblk^.tail) then n^.prev:=nw;
    nw^.prev:= eblk;
    nw^.next := n;
    if (eblk^.tail) then
    begin
        eblk^.tail:=false;
        nw^.tail:=true;
    end;
    {ok now the new block should be in the chain ok begin the data split}
    {we will take exactly half the data and move it to the next block}
    for i:= 1 to 50 do
    begin
        nw^.notes[i] := eblk^.notes[i+50];
    end;
    nw^.used:=50;
    eblk^.used:=50;
    {now determine where epos falls and adjust the position accordingly}
    if (epos>50) then
    begin
        epos:=epos-50;
        eblk := nw;
    end;
end;

procedure insert;{inserts a blank note (a rest with no length)}
var i:integer;
begin
    if (not(loaded) or (ech=-1)) then exit;
    {check if we need to split this block}
    if (eblk^.used=100) then split;
    {first we need to increase the used count}
    inc(eblk^.used);
    if epos<eblk^.used then inc(epos); {insert after current note}
    {now everything at epos up until the end needs to be moved one to the right}
    for i:= eblk^.used downto epos do
    begin
        eblk^.notes[i] := eblk^.notes[i-1];
    end;
    {need to set the new note to an no length rest}
    eblk^.notes[epos].note:=0;
    eblk^.notes[epos].leng:=0;
end;

procedure remove;{removes the note}
var p,n : blockptr;
    i:integer;
begin
    if (not(loaded) or (ech=-1)) then exit;
    if (eblk^.used=0) then exit; {none to remove}
    {shuffle all the notes backwards}
    for i:= epos to eblk^.used do
    begin
        eblk^.notes[i] := eblk^.notes[i+1];
    end;
    dec(eblk^.used);
    {check if this block is empty we can remove it (if it isn't the root)}
    if (eblk^.used>0) then exit;
    if ((eblk^.tail) and (eblk^.prev = nil)) then exit;
    {ok this is not the root and is empty perform the removal}
    p := eblk^.prev;
    n := eblk^.next;
    if not(p=nil) then p^.next:=n;
    if not(n=nil) then n^.prev := p;
    if (eblk^.tail) then p^.tail :=true;
    if (p = nil) then channels[ech] := n;
    dispose(eblk);
    if (n=nil) then
    begin
        eblk := p;
        epos := eblk^.used;
    end
    else
    begin
        eblk:= n;
        epos:= 1;
    end;    
end;

procedure setInstrument(inst:instrument);
begin
    if (not(loaded) or (ech=-1)) then exit;
    instruments[ech] := inst;
end;

{$f+}
procedure newexitproc;
begin
   unload; 
   exitproc:= exitsave;
end;
{$f-}

begin
    exitsave:=exitproc;
    exitproc:=@newexitproc;
    fmplayer.refillbuffer := refill;
    ech:=-1;
    epos:=1;
    nchan:=0;
    nsongs:=0;
    playing:=false;
    loaded:=false;
    dorepeat:=false;
end.
