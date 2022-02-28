{map unit for bobsfury... is backwards compatible with older versions!}
{A Danson}

unit map;

interface

{ define this option if you want to disable saving maps using RLE}
{define no_RLE}

procedure load(filename:string);
procedure save(filename:string);
function currentscreen:integer;
function objectat(x,y:integer):byte;
procedure setobjectat(x,y:integer; dat:byte);
procedure changescreen(n:integer);
procedure setobjat(x,y,s,l : integer; d:byte);
function getobjat(x,y,s,l : integer):byte;
{special routines ... for larger maps}
   function getSpecial:boolean;
   function getTier:integer;
   function getTierCount:integer;
   procedure setTier(l : integer);
   procedure setSpecial(s : boolean; size:byte);

   {target stuff :- for teleports and switches}
   type target	= record
		     x,y,screen,tier : byte;
		  end;		      
	trigger	=  record
		      source,dest : target;
		   end;

   procedure addtrigger(s,d : target);
   procedure deletetrigger(s : target);
   function gettarget(s : target;var dest:target):boolean;
   function isSource(s : target):boolean;
   function isDest(d : target):boolean;
   function triggerCount:integer;
   
implementation

uses buffer;

type tier=array[0..120,0..16] of byte; {the size of a tier within the map}
     tierptr=^tier;

var
   screen	: integer; {current screen in the tier}
   data		: tierptr; {pointer to current tier (vertically)}
   tiers	: array[0..11] of tierptr; {array of tiers}
   tiercount	: byte; {how many tiers are in this map (including the top one)}
   startpointer	: integer; {x distance into the tier for the current screen}
   exitsave	: pointer; {exit save to restore memory state}
   special	: boolean; {special indicates more than one tier}
   mem		: byte; {indicates how many tiers have been initialized!}
   ctier	: integer; {current tier within the map}
   triggers	: array[0..130] of trigger; {array of trigger (teleports, switches etc)}
   tnum		: byte; {trigger count}

procedure setobjat(x,y,s,l : integer; d:byte);
var lev : tierptr;
    p	: integer;
begin
   if ((l<0) or (l>=tiercount)) then exit;
   if ((s<1) or (s>4)) then exit;
   if ((x<0) or (x>30) or (y<0) or (y>15)) then exit;   
   lev:=tiers[l];
   p:=(s-1)*30;
   lev^[x+p,y]:=d;
end; { setobjat }

function getobjat(x,y,s,l : integer):byte;
var lev : tierptr;
    p	: integer;
begin
   getObjat:=1;
   if ((x<0) or (x>30) or (y<0) or (y>15)) then exit;
   if ((l<0) or (l>=tiercount)) then exit;
   if ((s<1) or (s>4)) then exit;
   lev:=tiers[l];
   p:=(s-1)*30;
   getobjat:=lev^[x+p,y];
end;

function triggerCount:integer;
begin
   triggerCount:=tnum;
end;

procedure addtrigger(s,d : target);
begin
   if tnum=131 then exit;
   triggers[tnum].source:=s;
   triggers[tnum].dest:=d;
   tnum:=tnum+1;
end; { addtrigger }
   
procedure deletetrigger(s : target);
var i : integer;
begin
   i:=0;
   while (i<tnum) do
   begin
      if ((triggers[i].source.x=s.x) and (triggers[i].source.y=s.y) and
	  (triggers[i].source.screen=s.screen) and
	  (triggers[i].source.tier=s.tier) ) then
      begin
	 triggers[i] := triggers[tnum-1];
	 tnum:=tnum-1;
	 i:=i-1;
      end;
      i:=i+1;
   end;
end; { deletetrigger }
   
function gettarget(s : target; var dest:target):boolean;
var i : integer;
begin
   gettarget:=false;
   i:=0;
   while (i<tnum) do
   begin
      if ((triggers[i].source.x=s.x) and (triggers[i].source.y=s.y) and
	  (triggers[i].source.screen=s.screen) and
	  (triggers[i].source.tier=s.tier) ) then
      begin
	 dest := triggers[i].dest;
	 gettarget:=true;	   
      end;
      i:=i+1;
   end;
end; { gettarget }

function isSource(s : target):boolean;
var d : target; 
begin
   isSource := gettarget(s,d);
end; { isSource }
   
function isDest(d : target):boolean;
var i : integer;
begin
   isdest:=false;
   i:=0;
   while (i<tnum) do
   begin
      if ((triggers[i].dest.x=d.x) and (triggers[i].dest.y=d.y) and
	  (triggers[i].dest.screen=d.screen) and
	  (triggers[i].dest.tier=d.tier) ) then
      begin
	 isdest:=true;	   
      end;
      i:=i+1;
   end;
end; { isDest }
   
procedure alloc(count : byte) ;
var
   i : integer;
begin 
   if mem=count then exit;
   settier(0);
   if mem>count then
   begin {we have allocated more than we need}
      for i:=count+1 to mem do
	 dispose(tiers[i]);
      mem:=count;
   end;
   if mem<count then
   begin
      for i:= mem+1 to count do
	 new(tiers[i]);
      mem:=count;
   end;
end;


function getSpecial:boolean;
begin
   getspecial:=special;
end; { getSpecial }
   
   
function getTier:integer;
begin
   getTier:=ctier;
end; { getLevel }

function getTierCount:integer;
begin
   getTierCount:=tierCount;
end; { getLevelCount }
   
procedure setTier(l : integer);
begin
   if l<0 then exit;
   if l>tierCount-1 then exit;
   if not(special) then exit;
   ctier:=l;
   data := tiers[l];
end; { setLevel }
   
procedure setSpecial(s : boolean; size:byte);
begin
   special:=s;
   if s then
   begin
      alloc(size-1);
      tierCount:=size;
   end
   else
   begin
      alloc(0);
      tierCount:=1;
   end;
end; { setSpecial }
   
function currentscreen:integer;
begin
   currentscreen:=screen;
end;

function objectat(x,y:integer):byte;
begin
   if ((x<0) or (x>30) or (y<0) or (y>15)) then
      begin
	 objectat := 1;
	 exit;
      end;
   objectat:=data^[x+startpointer,y];
end;

procedure setobjectat(x,y:integer; dat:byte);
begin
   if ((x<0) or (x>30) or (y<0) or (y>15)) then exit;
   data^[x+startpointer,y]:=dat;
end;

procedure changescreen(n:integer);
begin
   if ((screen<5) and (screen>0)) then
   begin
      screen:=n;
      startpointer:=(screen-1)*30;
   end;
end;

procedure writeLevelRLE(l : tierptr; var w : writer);
var
   i,c	 : integer;
   a	 : char;
   data	 : char;
   count : byte;
begin
   data := chr($FF); {initial value that is impossible}
   count := 0;
   w.writeChar(chr($FF)); {write the compression identifier}
   for i:= 0 to 16 do {compress!}
      for c:= 0 to 120 do {we are doing rows instead of columns to hopefully improve the compression rate}
	 begin
	    a := chr(l^[c,i]);
	    if ((a = data) and (count<255)) then
	    begin
	       inc(count);
	    end
	    else
	    begin
	       if (count>0) then
	       begin
		  w.writeChar(data);
		  w.writeChar(chr(count));
	       end;
	       count := 1;
	       data := a;
	    end;
	 end;
   if (count>0) then 
   begin
      w.writeChar(data);
      w.writeChar(chr(count));
   end;
end;

{$ifdef no_RLE}
procedure writeLevelRaw(l : tierptr; var w : writer);
var
   i,c : integer;
   a   : char;
begin
   i:=0;c:=0;
   while c<121 do
   begin
      a:= chr(l^[c,i]);
      w.writeChar(a);
      i:=i+1;
      if i=17 then
      begin
	 i:=0;
	 c:=c+1;
      end;
   end;
end;
{$endif}

procedure save(filename:string);
var mapfile:writer;
    i,c,z:integer;
    a:char;
begin
   mapfile.open(filename);
   {$ifdef no_RLE}
   writeLevelRaw(tiers[0], mapfile);
   {$else}
   writeLevelRLE(tiers[0], mapfile);
   {$endif}   
   a:=chr(0);
   if (special) then a:=chr($FF);
   if (special and (tierCount=8)) then a:=chr($FE);
   if (special and (tierCount=12)) then a:=chr($FD);
   mapfile.writeChar(a);
   if (special) then
   begin
      for z:=1 to tierCount-1 do
      begin
	 {$ifdef no_RLE}
	 writeLevelRaw(tiers[z],mapfile);
	 {$else}
	 writeLevelRLE(tiers[z],mapfile);
	 {$endif}
      end;
   end;
   for i:=0 to tnum-1 do
   begin
      a:=chr(triggers[i].source.x);
      mapfile.writeChar(a);
      a:=chr(triggers[i].source.y);
      mapfile.writeChar(a);
      a:=chr(triggers[i].source.screen);
      mapfile.writeChar(a);
      a:=chr(triggers[i].source.tier);
      mapfile.writeChar(a);
      a:=chr(triggers[i].dest.x);
      mapfile.writeChar(a);
      a:=chr(triggers[i].dest.y);
      mapfile.writeChar(a);
      a:=chr(triggers[i].dest.screen);
      mapfile.writeChar(a);
      a:=chr(triggers[i].dest.tier);
      mapfile.writeChar(a);
   end;
   mapfile.close;
end;

procedure readLevelRLE(l : tierptr; var r : reader);
var
   i,c	 : integer;
   data	 : char;
   count : byte;
begin
   data := r.readChar;
   count := ord(r.readChar);
   for i:= 0 to 16 do
      for c:= 0 to 120 do
	 begin
	    if (count>0) then
	    begin
	       l^[c,i] := ord(data);
	       dec(count);
	    end
	    else
	    begin
	       data := r.readChar;
	       count := ord(r.readChar);
	       l^[c,i] := ord(data);
	       dec(count);
	    end;
	 end;
end;

procedure readLevelRaw(l : tierptr; var r : reader);
var
   i,c : integer;
   a   : char;
begin
   a:= r.readChar;
   if (a = chr($FF)) then
   begin
      readLevelRLE(l,r);
      exit;
   end;
   l^[0,0] := ord(a);
   i:=1;c:=0;
   while c<121 do
   begin
      a:= r.readChar;
      l^[c,i]:=ord(a);
      i:=i+1;
      if i=17 then
      begin
	 i:=0;
	 c:=c+1;
      end;
   end;
end;


procedure load(filename:string);
var mapfile:reader;
    i,c,z:integer;
    a:char;
begin
   mapfile.open(filename);
   readLevelRaw(tiers[0],mapfile);
   special:=false;
   tierCount:=1;
   if not(mapfile.eof) then {if this is not the EOF load the special data}
   begin                      
      a:= mapfile.readChar;
      special:=false;
      if a=chr($FF) then
      begin
	 special:=true;
	 tierCount:=4;
      end;
      if a=chr($FE) then
      begin
	 special:=true;
	 tierCount:=8;
      end;
      if a=chr($FD) then
      begin
	 special:=true;
	 tierCount:=12;
      end;
      if special then
      begin
	 alloc(tierCount-1);
	 for z:= 1 to tierCount-1 do
	 begin
	    readLevelRaw(tiers[z], mapfile);
	 end;
      end;
   end;
   tnum:=0;
   while not(mapfile.eof) do {load triggers if the end of file is still not reached}
   begin
      i:=tnum;
      a:=mapfile.readChar;
      triggers[i].source.x:=ord(a);
      a:=mapfile.readChar;
      triggers[i].source.y:=ord(a);
      a:=mapfile.readChar;
      triggers[i].source.screen:=ord(a);
      a:=mapfile.readChar;
      triggers[i].source.tier:=ord(a);
      a:=mapfile.readChar;
      triggers[i].dest.x:=ord(a);
      a:=mapfile.readChar;
      triggers[i].dest.y:=ord(a);
      a:=mapfile.readChar;
      triggers[i].dest.screen:=ord(a);
      a:=mapfile.readChar;
      triggers[i].dest.tier:=ord(a);
      tnum:=tnum+1;
   end;
   mapfile.close;
   if (not(special)) then
   begin
      ctier:=0;
      data := tiers[0];
   end;
end;

{$F+}
procedure newExitProc;
var i : integer;
begin
   exitproc:=exitsave;
   dispose(tiers[0]);
   if (mem>0) then
      for i:=1 to mem do
	 dispose(tiers[i]);
end;
{$F-}

begin
   new(data);
   tiers[0] := data;
   ctier:=0;
   exitsave:=exitproc;
   exitproc:=@newexitproc;
   screen:=1;
   startpointer:=0;
   special :=false;
   tierCount:=1;
   mem:=0;
   tnum:=0;
end.
