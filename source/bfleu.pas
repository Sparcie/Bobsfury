{bob's fury level maker A Danson 2000}
{ math co-pro emulation and use turned off}
{$R-} {range checking off}
{$M 16384,0,655360} {memory}

{if you want a slim editor without the tester define notest}
{define notest}

{$I defines.pas}

program levelmaker;

uses map,keybrd,dos,bsystem, bobgraph, bfont, bsound
{$ifndef notest},engine
{$endif};

var hirs  : boolean;
   n	  : string;
   x,y	  : integer;
   ob	  : byte;
   dne	  : boolean;
   source : target;  {for teleports and switches}
   sm	  : boolean; {source marked}
   paint  : boolean;

function ginput(x,y:integer):string;
var z,s : string;
   done : boolean;
   a    : char;
   i    : integer;
begin
   z:='';
   done:=false;
   while not(done) do
   begin
      while not(keypressed) do;
      a:=readkey;
      s:=z+'_';
      textxy(x,y,4,0,s);
      if not((a=char(13)) or (a=char(8)) ) then z:=z+a;
      if a=char(13) then done:=true;
      if a=char(8) then
      begin
	 s:=z;
	 z:='';
	 for i:= 1 to length(s)-1 do z :=z + s[i];
      end;
      s:=z+'_';
      textxy(x,y,4,7,s);
   end;
   ginput:=z;
end;


function fileSelector( ext:string; wr:boolean):string;
var
   pge   :byte;
   pattern:string[12];
   list   :array[0..200] of string[12];
   count  :byte;
   pos    :byte;
   maxPos :byte;
   DirInfo:SearchRec;
   x, y   :word;
   k      :char;
   done   :boolean;
begin
    {First make a list of all the files with the extension}
    {prepare variables}
    pattern := '*.'+ext;
    count := 0;
    if wr then {if we are writing a file we may need to input a new file name}
    begin
        {make an entry for a new file}
        list[0] := 'New File';
        count :=1;
    end;
    {now build the list}
    FindFirst(pattern, 0, DirInfo);
    while DosError = 0 do
    begin
       if count < 201 then
       begin
           list[count] := DirInfo.name;
           inc(count);
       end;
       FindNext(DirInfo);
    end;

    fileSelector :='';
    if count=0 then exit;
    
    {Ok now we can do a file selection dialog box with the info we have}
    
    pge := 0;
    clearviewport;
    if wr then
       textxy(0,0,4,12,'Select a file to write')
    else
       textxy(0,0,4,9,'Select a file to read');
    
    x:=0; y:=16;
    pos:=0;
    {we can display at most 69 files per page at most}
    while ((pos<70) and (pos<count)) do
    begin
        textxy(x,y,4,7,list[pos]);
        inc(pos);
        x:= (pos mod 3) * 104;
        y:= ((pos div 3) * 8) + 16;
    end;
    maxPos := pos - 1;
    pos:=0;
    
    done:=false;
    {ok now we should be able to have a basic menu!}
    while not(done) do
    begin
        {highlight current position}
        x:= (pos mod 3) * 104;
        y:= ((pos div 3) * 8) + 16;
        textxy(x,y,4,10,list[pos + (pge*69)]);
        
        while not(keypressed) do ; {wait for a keypress!}
        
        {hide current selection}
        x:= (pos mod 3) * 104;
        y:= ((pos div 3) * 8) + 16;
        textxy(x,y,4,7,list[pos + (pge*69)]);
        
        {read and process keys}
        k := readkey;
        if k = chr(13) then
        begin {enter key pressed - do actions related to that!}
           pattern := list[pos];
           if ((wr) and (pos=0) and (pge=0)) then
           begin
               bar(0,0,200,15,0);
               textxy(0,0,4,9,'Enter new file...');
               pattern := ginput(0,8) + '.' + ext;               
           end;
           if wr then
           begin
              if (canWriteTo(pattern)) then done := true
              else
              begin
                 bar(160,0,319,16,0);
                 textxy(160,0,4,12,'Cannot write to '+pattern);
              end;
           end
           else
              done:=true;
           fileSelector := pattern;
        end;
        if k = chr(27) then
        begin {escape key pressed - no file selected!}
           fileSelector:= '';
           exit;
        end; 
        if k = chr(0) then {special key!}
        begin
           k := readkey; {read next key code...}
           
           {arrow keys}
           if ( (k = chr(75)) and (pos > 0)) then dec(pos);
           if ( (k = chr(72)) and (pos > 2)) then pos := pos - 3;
           if ( (k = chr(77)) and (pos < maxPos)) then inc(pos);
           if ( (k = chr(80)) and (pos < maxPos-2)) then pos := pos + 3;
           
           {deal with page-up/pagedown}
           if ( (k = chr(73)) or (k = chr(81))) then
           begin
              if ((pge>0) and (k = chr(73))) then dec(pge);
              if ((pge< (count div 69)) and (k = chr(81))) then inc(pge);

              bar(0,16,319,199,0);
              x:=0; y:=16;
              pos:=0;
              {we can display at most 69 files per page at most}
              while ((pos<70) and ((pos + (pge*69)) <count)) do
              begin
                 textxy(x,y,4,7,list[pos + (pge*69)]);
                 inc(pos);
                 x:= (pos mod 3) * 104;
                 y:= ((pos div 3) * 8) + 16;
             end;
             maxPos := pos - 1;
             pos:=0;                            
           end;           
        end;               
    end;
end;

{procedure listfiles;
var  DirInfo : SearchRec;
     x,y     : integer;
begin
   x:=0; y:=16;
   FindFirst('*.map',0, DirInfo);
   while DosError = 0 do
   begin
      textxy(x,y,4,7,DirInfo.Name);
      x:=x+(13*8);
      if (x>(320-96)) then
      begin
	 x:=0;
	 y:=y+8;
      end;
      FindNext(DirInfo);
   end;
end;  listfiles }

function isok(dat:byte):boolean;
begin
   case dat of
     0..16, 18..28, 30, 32, 34, 36, 38, 40, 42, 43, 45, 51, 54, 55, 57, 60, 62, 64, 66,
     77, 80..96, 116, 121, 123, 125, 136, 137, 138, 142, 147, 149, 150..154, 157, 160, 162..166, 170: isok:=true;
   else
      isok:=false;
   end;   
end;

procedure drawPaintIndicator;
var
   md : integer;
begin
   md:=1;
   if paint then md:=9;
   textxy(160,170,4,md,'Drawing');
end;

procedure drawSelection;
var i : integer;
   cs : integer;
   s  : string;
begin
   bar(0,169,11,180,7);
   spritedraw(1,170,ob,copyput);
   if ob = 0 then
   begin
      bar(1,170,10,179,0);
   end;
   cs:=ob;
   for i:= 1 to 14 do
   begin
      repeat
	 cs:=cs+1;
	 if cs>199 then cs:=0;
      until isok(cs);
      spritedraw(3+(i*10) ,170, cs, copyput);
      if cs = 0 then
      begin
	 bar(3+(i*10),170,13+(i*10),180,0);
      end;
   end;
   bar(0,185,30,195,0);
   str(ob, s);
   textxy(5,185,4,1,s);
end;

procedure easydraw(c,i:integer);
var md : integer;
   t   : target;
begin
   spritedraw(c*10,i*10,objectat(c,i),copyput);
   if objectat(c,i) = 0 then
   begin
      bar((c*10),(i*10),((c+1)*10)-1,((i+1)*10)-1,0);
   end;
   t.x:=c; t.y:=i; t.screen:=currentScreen; t.tier:=getTier;
   if (isSource(t)) then spritedraw(c*10,i*10,106,xorput);
   if (isdest(t)) then spritedraw(c*10,i*10,97,xorput);
end;

procedure startgraphics;
begin
   if hirs then
      graphicsMode:=3
   else
      graphicsMode:=2;
   bobgraph.startgraphics;
end;

procedure showscreen;
var i,c : integer;
   s,d	   : String[5];
begin
   clearviewport;
   line(0,161,311,161,7);
   line(311,0,311,161,7);
   i:=0;
   c:=0;
   while i<16 do
   begin
      easydraw(c,i);
      c:=c+1;
      if c=31 then
      begin
	 i:=i+1;
	 c:=0;
      end;
   end;
   drawSelection;
   drawPaintIndicator;
   bar(230,170,300,190,0);
   str(currentScreen,d);
   s:=d;
   str(getTier+1,d);
   s:= s +','+d;
   textxy(230,170,4,9,s);
   str(130 - triggerCount,d);
   textxy(160,180,4,1,'Triggers left:'+d);
end;

procedure init;
begin
    x:=1;
    y:=1;
    paint:=false;
    ob:=0;
    if paramstr(1) = '-h' then hirs:=true;
    startgraphics;
    initSound;
    map.load('default.map');
    showscreen;
end;

procedure help;
var pages      : array[1..16,1..5] of string[40];
   icons       : array[1..16,1..5] of word;
    page,x,y,i : integer;
    hdone,new  : boolean;
    a	       : char;
begin
   for i:=1 to 16 do
      for x:= 1 to 5 do icons[i,x]:=0;
   pages[1,1]:='Bob`s Fury Level Editing Utility';icons[1,1]:=28;
   pages[2,1]:='';
   pages[3,1]:='Programming: Andrew Danson';icons[3,1]:=59;
   pages[4,1]:='';
   pages[5,1]:='Press PageUp and PageDown ';
   pages[6,1]:='to scroll throught this text.';
   pages[7,1]:='';
   pages[8,1]:='This text should help you get';
   pages[9,1]:='started creating levels';
   pages[10,1]:='for Bob`s Fury';
   pages[11,1]:='';
   pages[12,1]:='The built in level';
   pages[13,1]:='tester is set to easy';
   pages[14,1]:='difficulty. So keep that';
   pages[15,1]:='in mind when designing ';
   pages[16,1]:='levels.';
   pages[1,2]:='Editor Keys';
   pages[2,2]:='F1 = This help Screen';
   pages[3,2]:='F2 = Save a map';
   pages[4,2]:='F3 = Load the map';
   pages[5,2]:='F4 = Flood fill';
   pages[6,2]:='F8 = Test level';
   pages[7,2]:='F9 = New/empty level';
   pages[8,2]:='F10 = Quit';
   pages[9,2]:='Cursor keys = move editing cursor';
   pages[10,2]:='Space = Toggle Drawing mode';
   pages[11,2]:='Enter = Place block/item';
   pages[12,2]:=', = Previous item';
   pages[13,2]:='. = Next item';
   pages[14,2]:='S = Set Special map (larger map)';
   pages[15,2]:='M = Show mini-map';
   pages[16,2]:='';
   pages[1,3]:='Additional Keys';
   pages[2,3]:='PageUp/PageDown ';
   pages[3,3]:='  = Change screens horizontally';
   pages[4,3]:='Home/End';
   pages[5,3]:='  = Change screens vertically';
   pages[6,3]:='T = Add trigger';
   pages[7,3]:='U = Delete trigger';
   pages[8,3]:='F = go to trigger destination';
   pages[9,3]:='The normal map size is 4x1 screens';
   pages[10,3]:=',by pressing S you can extend this ';
   pages[11,3]:='to 4x12.';
   pages[12,3]:='The player starts at the top';
   pages[13,3]:='left of the screen 1,1. This may be';
   pages[14,3]:='changed by placing a trigger there';
   pages[15,3]:='that points to the desired start ';
   pages[16,3]:='location';
   pages[1,4]:='Triggers';
   pages[2,4]:='';
   pages[3,4]:='Triggers are added by pressing';
   pages[4,4]:='the T key to set the desired start';
   pages[5,4]:='location, moving and then press';
   pages[6,4]:='T again to set the destination.';
   pages[7,4]:='';
   pages[8,4]:='Triggers are important for switches';
   pages[9,4]:='Teleporters and key holes. For the';
   pages[10,4]:='switch and key hole it designates';
   pages[11,4]:='an area to clear or place blocks';
   pages[12,4]:='when triggered. For Teleporters it';
   pages[13,4]:='sets the destination.';
   pages[14,4]:='Triggers set for monsters behave ';
   pages[15,4]:='like switches and trigger upon ';
   pages[16,4]:='the death of the monster.';
   pages[1,5]:='Tips';
   pages[2,5]:='';
   pages[3,5]:='Triggers for switches and keys can';
   pages[4,5]:='be daisy chained in order to';
   pages[5,5]:='affect a larger number of blocks.';
   pages[6,5]:='';
   pages[7,5]:='There are too many different blocks';
   pages[8,5]:='and items to describe here, create';
   pages[9,5]:='a test level and experiment with ';
   pages[10,5]:='them to get a feel for how they work.';
   pages[11,5]:='';
   pages[12,5]:='The built in tester uses the normal';
   pages[13,5]:='keyboard controls. press ESC to ';
   pages[14,5]:='show you a menu for the tester.' ;
   pages[15,5]:='To end a test press Q and then Y to';
   pages[16,5]:='return to the editor.';
   
   page:=1;
   new:=true;
   x:=25;
   y:=5;
   hdone:=false;
   while (not(hdone)) do
   begin
      if new then
      begin
	 bar(0,0,319,199,9);
	 bar(1,1,318,198,1);
      end;
      new:=false;
      for i:= 1 to 16 do
      begin
	 if not(hirs) then spritedraw(10,y+(i*10),icons[i,page],copyput);
	 textxy(x,y+(i*10),4,9,pages[i,page]);
      end;
      while (not(keypressed))do ;
	 
      a:=readkey;
      if (a=char(27)) then hdone:=true;
      if a=char(0) then
      begin
	 a:=readkey;
	 if a=char(81) then begin page:=page+1;new:=true; end;
	 if a=char(73) then begin page:=page-1;new:=true; end;
	 if page = 0 then begin page:=1;new:=false; end;
	 if page = 6 then begin page:=5;new:=false; end;
      end;
   end;
   showscreen;
end;

procedure load;
var name:string;
begin
   {clearviewport;
   textxy(0,0,4,9,'Type in the name of a map to load');
   listfiles;
   name:= ginput(0,8);}
   name := fileSelector('map', false);
   if checkFile(name) then
      map.load((name));
   showscreen;
end;

procedure save;
var name :string;
begin
{   clearviewport;
   textxy(0,0,4,9,'Save this map as...');
   listfiles;
   name:= ginput(0,8);}
   name := fileSelector('map', true);
   if not(name='') then
      map.save((name));
   showscreen;
end;

procedure fill(i,c,tb :byte);
begin
   if (ob=objectAt(i,c)) then exit;
   if i<0 then exit;
   if i>30 then exit;
   if c<0 then exit;
   if c>15 then exit;
   if objectat(i,c)=tb then
   begin
      setObjectAt(i,c,ob);
      fill(i+1,c,tb);
      fill(i,c+1,tb);
      fill(i-1,c,tb);
      fill(i,c-1,tb);
   end;
{ for i:=0 to 30 do
  for c:=0 to 15 do
   begin
   setobjectat(i,c,ob);
   end;}
end;

procedure new;
begin
    map.load('default.map');
    showscreen;
end;

procedure drawcursor;
begin
 easydraw(x,y);
 spritedraw(x*10,y*10,49,xorput);
end;

{$ifndef notest}
{Cheater menu for the tester!}
{ this won't draw as nicely in hires mode for lack of bobgraph usage here}
procedure cheatMenu;
var 
   c	  : char;
   done	  : boolean;
begin
   while keypressed do
      c:= readkey;
   {bobgraph.save(0,0,260,100);}
   engine.hideMonsters;
   clearanims;
   {display the list of options for cheating!}
   bar(0,0,260,100,9);
   bar(1,1,259,99,1);
   textxy(20,1,4,12,'Cheat menu for Tester!');
   textxy(15,10,4,9,'H = Extra Health bottles');
   textxy(15,20,4,9,'I = Invulnerability');
   textxy(15,30,4,9,'L = Lightning Bolts');
   textxy(15,40,4,9,'G = Grenades');
   textxy(15,50,4,9,'V = Lives');
   textxy(15,60,4,9,'Esc or Q back to game test');
   textxy(15,70,4,9,'R = Return to editor');
   spritedraw(1,10,9,copyput);
   spritedraw(1,20,10,copyput);
   spritedraw(1,30,50,copyput);
   spritedraw(1,40,49,copyput);
   spritedraw(1,50,107,copyput);
   spritedraw(1,60,29,copyput);
   spritedraw(1,70,59,copyput);
   {ok decide what to do!}
   done:=false;
   while not(done) do
   begin
      while not(keypressed) do ;  {nothing until keypress!}
	 c:= UpCase(Readkey);
      case c of
	'H'	     : inc(player.fullb);
	'I'	     : player.invuln := 450;
	'L'	     : player.lbolt:= player.lbolt + 100;
	'G'	     : player.gren:= player.gren + 20;
	'V'	     : inc(player.lives);
	'Q', chr(27) : done:=true;
	'R'          : begin
	   successful:=true;
	   done:= true;
	end;
      end;
   end;
   clearviewport;
   bobgraph.showscreen;
   drawPlayer;
   drawAllBullets;
   {restore;}
end;
{$endif}

procedure test;
begin
   {$ifndef notest}
   map.save('#btest#.map');
   
   gap:=2;
   diff:=5;
   respawn:=false;
   engine.clearmonsters;
   
   newlevel('','#btest#.map');
   clearviewport;
   engine.newscreen(currentscreen,getTier);
   player.lives:=3;
   player.health:=100;
   player.score := 0;
   player.fullb := 10;
   player.gren := 10;
   player.lbolt := 50;
   player.keys :=0;
   player.flyer :=false;
   successful:=false;
   drawplayer;
   checkTimer;
   while ((player.lives>0) and not(successful)) do
   begin
      run;
      if menu then
      begin
	 cheatMenu;
	 menu:=false;
      end;
   end;
   
   map.load('#btest#.map');
   showscreen;
   {$endif}
end;

procedure specialkeys;
var a:char;
begin
   a:=readkey;
   case a of
     chr(72) : if y>0 then y:=y-1;
     chr(80) : if y<15 then y:=y+1;
     chr(75) : if x>0 then x:=x-1;
     chr(77) : if x<30 then x:=x+1;
     chr(66) : test;
     chr(67) : new;
     chr(59) : help;
     chr(60) : save;
     chr(61) : load;
     chr(62) : begin
	fill(x,y,objectat(x,y));
	showscreen;
     end;
     chr(68) : dne:=false;
     chr(73) : begin
	if currentscreen > 1 then changescreen(currentscreen-1);
	showscreen;
     end;
     chr(81) : begin
	if currentscreen < 4 then changescreen(currentscreen+1);
	showscreen;
     end;
     chr(71) : if getspecial then
     begin
	if getTier >0  then setTier(getTier-1);
	showscreen;
     end;
     chr(79) : if getspecial then
     begin
	if (getTier < getTierCount-1)  then setTier(getTier+1);
	showscreen;
     end;
   end;
end;

procedure trigger;
var t : target;
begin
   t.x:=x;
   t.y:=y;
   t.screen:=currentscreen;
   t.tier:=getTier;
   if sm then addtrigger(source,t) else source:=t;
   showscreen;
   sm := not(sm);
end;

procedure dtrigger;
var t : target;
begin
   t.x:=x;
   t.y:=y;
   t.screen:=currentscreen;
   t.tier:=getTier;
   deletetrigger(t);
   showscreen;
end;

procedure follow;
var
   s,d : target;
begin
   s.x:=x;
   s.y:=y;
   s.tier:=getTier;
   s.screen:=currentscreen;
   if not(gettarget(s,d)) then exit;
   x:=d.x;
   y:=d.y;
   changescreen(d.screen);
   setTier(d.tier);
   showScreen;
end; { follow }

procedure setMapSize; {for setting how big the map is (up to 4x12 in size)}
var
   sel	   : integer;
   a	   : char;
   l,s,i,c : integer;
begin
   if getSpecial then exit;
   sel:=1;
   textxy(0,0,4,9,'Select a map size');
   textxy(10,10,4,9,'4x1');
   textxy(10,20,4,9,'4x4');
   textxy(10,30,4,9,'4x8');
   textxy(10,40,4,9,'4x12');
   spritedraw(0,sel*10,49,copyput);
   while true do
   begin
      while not(keypressed) do ; {nothing until a key is pressed}
      a:= readkey;
      if a=chr(0) then a:=readkey;
      spritedraw(0,sel*10,49,xorput);
      if ((a=chr(72)) and (sel>1)) then sel:=sel-1;
      if ((a=chr(80)) and (sel<4)) then sel:=sel+1;
      spritedraw(0,sel*10,49,copyput);
      if a=chr(13) then
      begin
	 sel:=(sel-1)*4;
	 if sel=0 then
	 begin
	    showScreen;
	    exit;
	 end;
	 setSpecial(true,sel);
	 {we need to erase the new level data because it is likely to contain junk}
	 for l := 1 to getTierCount-1 do
	    for s:= 1 to 4 do
	       for i:= 0 to 30 do
		  for c:= 0 to 15 do
		     setObjAt(i,c,s,l,0);
	 showScreen;
	 exit;
      end;      
   end;
end;

{this function returns the map colour associated with an object}
function mapColour(ob : byte):byte;
begin
   case ob of
     0:mapColour:=0;
     1..8: mapColour:=4;
     9,10,82,83,149..152: mapColour:=2;
     11..13:mapColour:=42;
     14,80,81:mapColour:=9;
     15:mapColour:=1;
     16,30,32,34,36,38,40,42,43,55,57,60,62,121,123,138	: mapColour:=12;
     28,45,64,66,77:mapColour:=13;
     51,54,116,142,147,157:mapColour:=5;
     18..20,87..96,136,137:mapColour:=8;
     21: mapColour:=10;
     22..27,125: mapColour:=14;
     153,154,84..86: mapColour:=3;
   end;
end;

function treasureValue(t : byte):integer;
begin
   treasureValue := 0;
   case t of
     22	 : treasureValue:=25;
     23	 : treasureValue:=50;
     24	 : treasureValue:=75;
     25	 : treasureValue:=100;
     26	 : treasureValue:=125;
     27	 : treasureValue:=150;
     125 : treasureValue:=300;
   end;
end;

function isMonster(o : byte):boolean;
begin
   isMonster:=false;
   case o of
     16,28..55,57..78, 116, 121, 123, 138, 142, 147, 157, 166 : isMonster:=true;
   end;
end;

procedure levelMap;
var
   i,c,s,t	: integer;
   o		: byte;
   os,ol,l	: integer;
   a		: char;
   output	: string;
   treasures	: longint;
   monsterCount	: integer;
begin
   treasures := 0;
   monsterCount := 0;
   os:=currentscreen;
   ol:=getTier;
   bar(0,0,(31*4)+1,(16*12)+1,7);
   bar(0,0,(31*4),(16*12),8);
   {display level 1 in map }
   setTier(0);
   for s:=1 to 4 do
   begin
      changescreen(s);	 
      for i:= 0 to 15 do
	 for c:=0 to 30 do
	 begin
	    o := objectat(c,i);
	    t:= mapColour(o);
	    treasures := treasures + treasureValue(o);
	    if isMonster(o) then inc(monsterCount);
	    bar(c+((s-1)*31),i,c+((s-1)*31),i,t);
	 end;
   end;
   
   if (getSpecial) then
      for l:=1 to getTierCount-1 do
      begin
	 setTier(l);
	 for s:=1 to 4 do
	 begin
	    changescreen(s);	 
	    for i:= 0 to 15 do
	       for c:=0 to 30 do
	       begin
		  o := objectat(c,i);
		  t:= mapColour(o);
		  if isMonster(o) then inc(monsterCount);
		  treasures := treasures + treasureValue(o);
		  bar(c+((s-1)*31),i+(l*16),c+((s-1)*31),i+(l*16),t);
	       end;
	 end;
      end;

   bar(127,20,275,42,0);
   
   str(treasures, output);
   output := 'Treasure Value: '+ output;
   textxy(130,20,4,9,output);

   str(monsterCount, output);
   output := 'Monsters: '+output;
   textxy(130,30,4,9,output);
   
   while not(keypressed) do ;
   a:=readkey;
   a:=chr(1);
   changescreen(os);
   setTier(ol);
   bar(0,0,(31*4)+1,(16*12)+1,0);
   showscreen;
end;

procedure checkkeys;
var i,c,s,t : integer;
   os,ol,l       : integer;
    a	       : char;
begin
 if keypressed then
 begin
    easydraw(x,y);
    a:=readkey;
    if a = chr(0) then specialkeys;
    if paint then setobjectat(x,y,ob); 
    a:=upcase(a);
    case a of
      'S' : setMapSize;
      'T' : trigger;
      'U' : dtrigger;
      'F' : follow;
      ' ' : begin
	 if not(paint) then setobjectat(x,y,ob);
	 paint := not(paint);
	 drawPaintIndicator;
      end;
      'M' : begin
	 levelMap;
      end;
      '.' : begin
	 repeat
	    ob := ob+1;
	    if ob>199 then ob:=0;
	 until isok(ob);
	 drawSelection;
      end;
      ',' : begin
	 repeat
	    if ob=0 then ob:=200;
	    ob:=ob-1;
	 until isok(ob);
	 drawSelection;
      end;
      chr(13), chr(8) : setobjectat(x,y,ob);
    end;
    drawcursor;
 end;
end;

begin
   loadFont('litt.chr');
   init;
   sm:=false;
   dne:=true;
   drawSelection;
   while dne do
   begin
      checkkeys;
   end;
   finish;
end.
