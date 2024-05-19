unit bmenu;
{bobs fury menu system also added high score system
A Danson 2002}

{$I defines.pas}

interface

uses llist;

procedure gamemenu;
procedure intro;
procedure endGame(score:longint);

{shows level text}
procedure doleveltext(title : string; txt:leveltext); 
{shows the level title when there is no text}
procedure leveltitle(title : string);


implementation
uses bobgraph,bfont,engine,map,bsound,bsystem,bjoy,keybrd,pgs,pitdbl
{$ifndef noAdlib}
 ,fmplayer
{$endif}
;

type
	score=record
		name:string[30];
		score:longint;
		end;

var scorez    : array[0..9] of score;
   statereset : boolean; {indicates that the monsters array was emptied in order to save (or other function)}
   menudepth  : integer; {stores how many menus deep we are before returning.}

function ginput(s:string;x,y:integer):string;
var done:boolean;
    a:char;
    z,olds:string;
    i:integer; 
begin
   done := false;
   olds:=s;
   while (not(done)) do
   begin
      {bobgraph.bar(x,y,300,45,0);}
      textxy(x,y,4,0,olds + '_');
      textxy(x,y,4,UIColours[7],s + '_');
      olds:=s;
      while not(keypressed) do checkSongChange;
      a:=readkey;
      if (not(a=char(13)) and not(a=char(0)) and not(a=char(8))) then s:=s+a;
      if a=char(8) then
      begin
	 z:=s;
	 s:='';
	 for i:=1 to length(z)-1 do s :=s+ z[i];
      end;
      if (a=char(0)) then a:=readkey;
      if length(s) = 27 then done:=true;
      if a=char(13) then done:=true;
      if ((length(s)=0) and done) then done:=false;
   end;
   ginput:=s;
end;

function checkSaveSlot( s :integer):boolean;
var f:string;
begin
   checkSaveSlot :=false;
   str(s,f);
   f:= 'save'+f+'.dat';
   checkSaveSlot := checkFile(f);
end;

function saveSlotName( s :integer):string;
var f,n:string;
    out:text;
begin
   if not(checkSaveSlot(s)) then
   begin
      saveSlotName:='empty';
      exit;
   end;
   str(s,f);
   f:= 'save'+f+'.dat';
   assign(out,f);
   reset(out);
   readln(out,n);
   close(out);
   saveSlotName:=n;
end;

procedure startmenu;
var
   pic			 : integer;
begin
   {engine.clearmonsters;}
   if not(paging) then
   begin
      engine.hideMonsters;
      clearanims;
   end
   else
      UIPage;

   {bobgraph.bar(0,0,319,199,7);}
   {border of white going to grey black
   bobgraph.bar(0,0,319,199,15);
   bobgraph.bar(1,1,318,198,7);
   bobgraph.bar(2,2,317,197,8);
   bobgraph.bar(3,3,316,196,0);}
   
   {draw bricks on the top and bottom rows
   bobgraph.bar(0,0,319,199,0);
   pic:= random(8)+1;
   for i:= 0 to 31 do
   begin
      spritedraw(i*10,0,pic,copyput);
      spritedraw(i*10,189,pic,copyput);     
   end;}

   {bricks in the corners with lines for borders}
   pic:= random(8)+1;

   clearviewport;
   
   bobgraph.bar(0,0,319,1,UIColours[15]);
   bobgraph.bar(0,1,319,2,UIColours[7]);
   bobgraph.bar(0,2,319,3,UIColours[8]);
   bobgraph.bar(0,3,319,4,0);

   bobgraph.bar(0,198,319,199,UIColours[15]);
   bobgraph.bar(0,197,319,198,UIColours[7]);
   bobgraph.bar(0,196,319,197,UIColours[8]);
   bobgraph.bar(0,195,319,196,0);

   bobgraph.bar(0,0,1,199,UIColours[15]);
   bobgraph.bar(1,0,2,199,UIColours[7]);
   bobgraph.bar(2,0,3,199,UIColours[8]);
   bobgraph.bar(3,0,4,199,0);
   
   bobgraph.bar(319,0,318,199,UIColours[15]);
   bobgraph.bar(318,0,317,199,UIColours[7]);
   bobgraph.bar(317,0,316,199,UIColours[8]);
   bobgraph.bar(316,0,315,199,0);
   
   spritedraw(0,0,pic,copyput);
   spritedraw(0,190,pic,copyput);
   spritedraw(310,0,pic,copyput);
   spritedraw(310,190,pic,copyput);
   inc(menuDepth);   
end;

procedure menudone;
begin
   dec(menuDepth);
   if (menuDepth>0) then exit;
   checkTimer;
   if ((paging) and not(stateReset)) then
   begin
      GamePage;
      exit;
   end;
   if (paging) then GamePage;
   if statereset then
      engine.newscreen(currentscreen,getTier)
   else
   begin
      clearviewport;
      showscreen;
   end;
   {spritedraw(player.x,player.y,newf+106,xorput);}
   drawPlayer;
   drawAllBullets;
   statereset:=false;
end;

procedure leveltitle(title : string);
var
   x	 : word;
   a	 : char;
   nextt : word;
begin
   while keypressed do a:=readkey;
   startmenu;
   statereset:=true;
   textxy(100,20,4,UIColours[9],title);
   x:=0;
   spritedraw(x,40,107,xorput);
   nextt := timertick + pitRatio;
   while (not(keypressed) and (x<310)) do
   begin
      if (timerTick>=nextt) then
      begin
	 nextt:=timerTick + pitRatio;
	 spritedraw(x,40,107+((x div 2) mod 2),xorput);
	 x:=x+2;
	 spritedraw(x,40,107+((x div 2) mod 2),xorput);
	 checkSongChange;
      end;
   end;
   if keypressed then a:=readkey;
   engine.clearmonsters;   
   menudone;   
end; { leveltitle }

procedure doleveltext(title : string; txt:leveltext);
var i   : integer;
   done : boolean;
   a    : char;
begin
   while keypressed do a:=readkey;
   if txt.size=0 then exit;
   startmenu;
   statereset:=true;
   textxy(10,10,4,UIColours[9],title);
   for i:= 0 to txt.size-1 do
   begin
      textxy(10,20+(i*10),4,UIColours[7],txt.data[i]);
   end;
   done:=false;
   while not(done) do
   begin
      checkSongChange;
      a:=chr(1);
      if keypressed then a:=readkey;
      if ((a=chr(13)) or (a=' ')) then done:=true;
   end;
   engine.clearmonsters;
   menudone;
end;

procedure begingame;
var infile       : text;
    epname       : array[1..30] of string[25];
    epdir        : array[1..30] of string[8];
    no,x,y,i,sel : integer;
    bgdone       : boolean;
    a            : char;
   eptext        :leveltextptr;
begin
   new(eptext);
   sel:=1;
   assign(infile,'.\epps.lst');
   reset(infile);
   no:=0;
   while not Eof(infile) do
   begin
      no:=no+1;
      if no>30 then no:=1;
      readln(infile,epname[no]);
      readln(infile,epdir[no]);
   end;
   close(infile);
   startmenu;
   x:=60;
   y:=30;
   textxy(50,10,4,UIColours[9],'Pick An Episode To Play :-');
   for i:= 1 to no do
   begin
      textxy(x,y+(i*10),4,UIColours[5],epname[i]); 
   end;
   bgdone:=false;
   while (not(bgdone)) do
   begin
      textxy(x,y+(sel*10),4,UIColours[13],epname[sel]);
      while (not(keypressed)) do checkSongChange;
      textxy(x,y+(sel*10),4,UIColours[5],epname[sel]);
      a:=readkey;
      if a=char(27) then bgdone:=true;
      if a=char(0) then
      begin
	 a:=readkey;
	 if a=char(80) then sel:=sel+1;
	 if a=char(72) then sel:=sel-1;
	 if sel<1 then sel:=no;
	 if sel>no then sel:=1;
      end; 
      if a=char(13) then
      begin
	 successful:=false;
	 statereset:=true;
	 player.lives:=3;
	 player.health:=100;
	 player.score:=0;
	 player.invuln:=0;
	 bgdone:=true;
	 player.fullb:=0;
	 player.gren :=0;
	 player.lbolt:=0;
	 player.keys :=0;
	 player.flyer := false;
	 engine.clearmonsters;
	 loadepisode(epdir[sel]);
	 if gettext(0,eptext^) then doleveltext(epname[sel],eptext^);
	 nextlevel;
	 if gettext(llist.getlevel,eptext^) then doleveltext(getlevelname,eptext^)
	 else
	    leveltitle(getlevelname);
      end;
   end;
   dispose(eptext); 
   menuDone;
end;

procedure savegame;
var slots : array[1..9] of string[50];
   i,sel  : integer;
   sdone  : boolean;
   a	  : char;
   buff	  : array[1..sizeof(playerrec)] of char;
   out	  : text;
   t	  : byte;
const	  
    slotfile:array[1..9] of string[8] = ('save1','save2','save3','save4','save5','save6','save7','save8','save9');
begin
   if ((player.lives=0) and (not(successful))) then exit;
   startmenu;
   for i:=1 to 9 do
      slots[i] := saveSlotName(i);
   textxy(30,30,4,9,'pick a slot to save too...');
   for i:= 1 to 9 do
   begin
      textxy(30,40 + i*10,4,UIColours[5],slots[i]);
   end;
   sel:=1;
   sdone:=false;
   while (not(sdone)) do
   begin
      textxy(30,40+(sel*10),4,UIColours[13],slots[sel]);
      while (not(keypressed)) do checkSongChange;
      
      textxy(30,40+(sel*10),4,UIColours[5],slots[sel]);
      
      a:=readkey;
      if a=char(27) then sdone:=true;
      if a=char(13) then 
      begin
	 sdone:=true;
	 inc(statereset);
	 engine.clearMonsters;
	 {saving game here yah!}
	 textxy(30,40+(sel*10),4,0,slots[sel]);
	 slots[sel] := ginput(slots[sel],30,40+(sel*10));
	 { we need to check if we can write to the save file }
	 if not(canWriteTo(slotfile[sel]+'.map') and canWriteTo(slotfile[sel]+'.dat')) then
         begin
	    {we have determined we can't save due to write protection most likely}
	    textxy(40, 150, 4, UIColours[12], 'Cannot write save file');
	    while (not(keypressed)) do ; {wait for a key}
            while keypressed do a:=readkey;
	    menudone;
	    exit;
	 end;	 
	 map.save(slotfile[sel]+'.map');
	 move(player,buff,sizeof(playerrec));
	 assign(out,slotfile[sel]+'.dat');
	 rewrite(out);
	 writeln(out,slots[sel]);
	 writeln(out,eppath);
	 t:=nl;
	 write(out,char(t));
	 t:=currentScreen;
	 write(out,char(t));
	 t:=getTier;
	 write(out,char(t));
	 for t:=1 to sizeof(playerrec) do
	 begin
	    write(out,buff[t]);
	 end;
	 close(out);
      end;
      if a=char(0) then 
      begin
	 a:=readkey;
	 if a=char(80) then sel:=sel+1;
	 if a=char(72) then sel:=sel-1;
	 if sel=0 then sel:=9;
	 if sel=10 then sel:=1;
      end;
   end;
   menudone;
end;

procedure loadgame;
var slots    : array[1..9] of string[50];
   slotfile  : array[1..9] of string[8];
   i,sel,nss : integer;
   sdone     : boolean;
   a	     : char;
   buff	     : array[1..sizeof(playerrec)] of char;
   out	     : text;
   t	     : byte;
const
   savefile:array[1..9] of string[8] = ('save1','save2','save3','save4','save5','save6','save7','save8','save9');
begin
   
   nss:=0;
   for i:=1 to 9 do
   begin
      if checkSaveSlot(i) then
      begin
	 nss:=nss+1;
	 slots[nss]:=saveSlotName(i);
	 slotfile[nss]:=savefile[i];
      end;
   end;
   if (nss=0) then exit;
   startmenu;
   textxy(30,30,4,UIColours[9],'pick a slot to load from...');
   for i:= 1 to nss do
   begin
      textxy(30,40 + i*10,4,UIColours[5],slots[i]);
   end;
   sel:=1;
   sdone:=false;
   while (not(sdone)) do
   begin
      textxy(30,40+(sel*10),4,UIColours[13],slots[sel]);
      while (not(keypressed)) do checkSongChange;
      
      textxy(30,40+(sel*10),4,UIColours[5],slots[sel]);
      
      a:=readkey;
      if a=char(27) then sdone:=true;
      if a=char(13) then 
      begin
	 sdone:=true;
	 statereset:=true;
	 engine.clearMonsters;
	 {loading game here yah!}
	 map.load(slotfile[sel]+'.map');
	 assign(out,slotfile[sel]+'.dat');
	 reset(out);
	 readln(out,slots[sel]);
	 readln(out,eppath);
	 read(out,char(t));
	 loadepisode(eppath);
	 nl:=t;
	 read(out,char(t));
	 changescreen(t);
	 read(out,char(t));
	 setTier(t);
	 for t:=1 to sizeof(playerrec) do
	 begin
	    read(out,buff[t]);
	 end;
	 close(out);
	 move(buff,player,sizeof(playerrec));
	 successful:=false;
      end;
      if a=char(0) then 
      begin
	 a:=readkey;
	 if a=char(80) then sel:=sel+1;
	 if a=char(72) then sel:=sel-1;
	 if sel=0 then sel:=nss;
	 if sel=(nss+1) then sel:=1;
      end;
   end;
   menudone;
end;

procedure joycal;
var done : boolean;
   jx,jy : integer;
   c     : byte;
   a     : char;
   fa,fb,fc,fd: byte;
   sel   : integer;
const
   functs : array[0..4] of string[8] = ('none', 'Fire', 'Jump', 'Weapon', 'Health');
begin
   fa := 0;
   fb := 0;
   fc := 0;
   fd := 0;
   sel := -1;
   for c:= 1 to 4 do
   begin
     if (jcbuttons[c] = BUTTON_A) then fa := c;
     if (jcbuttons[c] = BUTTON_B) then fb := c;
     if (jcbuttons[c] = BUTTON_C) then fc := c;
     if (jcbuttons[c] = BUTTON_D) then fd := c;
   end;
   startmenu;
   textxy(10,10,4,UIColours[9],'centre joystick and press C');
   textxy(100,80,4,UIColours[7],functs[fa]);
   textxy(100,90,4,UIColours[7],functs[fb]);
   textxy(100,100,4,UIColours[7],functs[fc]);
   textxy(100,110,4,UIColours[7],functs[fd]);
   textxy(20,120,4,UIColours[2],'Done');
   spritedraw(6,80+(sel*10),44,xorput);
   done:=false;
   while not(done) do
   begin
      checkSongChange;
      update;
      jx:=45;
      jy:=45;
      if keypressed then
      begin
	 a:=readkey;
	 if ((a='c') or (a='C')) then calibrate;
         if (a=chr(27)) then done:=true;
         if ((a=chr(13)) and (sel=4)) then done:=true;
         if (a=chr(0)) then
         begin
	    a := readkey;
            spritedraw(6,80+(sel*10),44,xorput);
	    bobgraph.bar(100,80,170,125,0);
            if a=chr(72) then dec(sel);
            if a=chr(80) then inc(sel);
            if (sel=-2) then sel := 4;
            if (sel=5) then sel := -1;
	    if ((a=chr(75)) or (a=chr(77))) then
            begin
               case sel of
                 -1 : usejoy := not(usejoy);
                  0 : inc(fa);
                  1 : inc(fb);
                  2 : inc(fc);
                  3 : inc(fd);
                  4 : done := true;
               end;
               if fa=5 then fa:=0;
               if fb=5 then fb:=0;
               if fc=5 then fc:=0;
               if fd=5 then fd:=0;
            end;
            textxy(100,80,4,UIColours[7],functs[fa]);
            textxy(100,90,4,UIColours[7],functs[fb]);
            textxy(100,100,4,UIColours[7],functs[fc]);
            textxy(100,110,4,UIColours[7],functs[fd]);
            spritedraw(6,80+(sel*10),44,xorput);
         end;
      end;
      if not(xcentred) then
      begin
	 if (joy.xaxis<joy.xcentre) then jx:=30 else jx:=60;
      end;
      if not(ycentred) then
      begin
	 if (joy.yaxis<joy.ycentre) then jy:=30 else jy:=60;
      end;
      bobgraph.bar(29,29,61,61,UIColours[8]);
      bobgraph.bar(jx,jy,jx+1,jy+1,UIColours[9]);
      c:= 2;
      if (usejoy) then c:=10;
      textxy(20,70,4,UIColours[c],'Joystick Enabled');
      c:= 2;
      if (joy.buttons and BUTTON_A) = 0 then c:=10;
      textxy(20,80,4,UIColours[c],'Button A');
      c:= 2;
      if (joy.buttons and BUTTON_B) =0 then c:=10;
      textxy(20,90,4,UIColours[c],'Button B');      
      c:= 2;
      if (joy.buttons and BUTTON_C) =0 then c:=10;
      textxy(20,100,4,UIColours[c],'Button C');
      c:= 2;
      if (joy.buttons and BUTTON_D) =0 then c:=10;
      textxy(20,110,4,UIColours[c],'Button D'); 
   end;
   for c:= 1 to 4 do
   begin
     jcbuttons[c] := 0;
     if (fa=c) then jcbuttons[c] := BUTTON_A;
     if (fb=c) then jcbuttons[c] := BUTTON_B;
     if (fc=c) then jcbuttons[c] := BUTTON_C;
     if (fd=c) then jcbuttons[c] := BUTTON_D;
   end;
   menudone;
   dec(menuDepth);
   startmenu;
end; { joycal }

{pick a key for a control - ind is a index into the array of customisable keys (see custom keys for which are which)}
procedure pickKey(ind :word) ;
var
   a : char;
begin
   {make sure no keys waiting in the buffer}
   while keypressed do a:=readkey;

   {wait for a keypress}
   while not keypressed do checkSongChange;

   clearKey(ind);
   scancode[ind]:=lastKeyPressed;

   {clear the keys from the buffer}
   while keypressed do a:=readkey;   
end;

{Keyboard customisation section - fills out the scan codes in the keybrd unit}
procedure customKeys;
var
   pos	: integer; {position in the menu}
   keys	: array[1..7] of string[20];
   c	: word;
   done	: boolean;
   a	: char;
begin
   startmenu;
   pos:=0;
   keys[1]:='Left';
   keys[2]:='Right';
   keys[3]:='Fire';
   keys[4]:='Jump';
   keys[5]:='Select weapon';
   keys[6]:='Use bottle';
   keys[7]:='Toss Grenade';

   {ok we have initialised the basics to drive this menu lets deal with displaying the menu}
   c:=5;
   if useCustomKeys then c:=13;
   textxy(40,40,4,UIColours[c],'Custom Keyboard controls');
   for c:= 1 to 7 do
   begin
      textxy(40,40+(c*10),4,UIColours[5],keys[c]);
      textxy(130,40+(c*10),4,UIColours[5],keyface(scancode[c]));
   end;
   textxy(40,120,4,UIColours[9],'Done');
   
   spritedraw(29,43+(pos*10),44,copyput);
   { init done... watch for the different key presses required }
   done:=false;

   while not(done) do
   begin
      while not(keypressed) do checkSongChange;

      a:= readkey;
      if a = chr(27) then done:=true;
      if a = chr(13) then
      begin
	 if ((pos>0) and (pos<8)) then
	 begin
	    textxy(40,40+(pos*10),4,0,keys[pos]);
	    textxy(130,40+(pos*10),4,0,keyface(scancode[pos]));
	    pickkey(pos);
	    textxy(40,40+(pos*10),4,UIColours[13],keys[pos]);
	    textxy(130,40+(pos*10),4,UIColours[13],keyface(scancode[pos]));
	 end;
	 if pos = 8 then done:=true;
	 if pos = 0 then
	 begin
	    {this is where we will toggle the custom controls}
	    useCustomKeys:=not(useCustomKeys);
	    c:=5;
	    if useCustomKeys then c:=13;
	    textxy(40,40,4,UIColours[c],'Custom Keyboard controls');
	 end;
      end;
      if a = chr(0) then
      begin {special keys (up and down arrows to change position)}
	 a:=readkey;
	 {keys 72 = up 80 = down}
	 {clear current highlighted item}
	 spritedraw(29,43+(pos*10),44,xorput);
	 if ((pos>0) and (pos<8)) then
	 begin
	    textxy(40,40+(pos*10),4,UIColours[5],keys[pos]);
	    textxy(130,40+(pos*10),4,UIColours[5],keyface(scancode[pos]));
	 end;
    
	 if a = chr(72) then
	 begin
	    dec(pos);
	    if pos=-1 then pos:=8;
	    if (not(useCustomKeys) and (pos=7)) then pos:=0
	 end;
	 if a = chr(80) then 
	 begin
	    inc(pos);
	    if pos=9 then pos:=0;
	    if (not(useCustomKeys) and (pos=1)) then pos:=8
	 end;
	 {redraw highlighted item}
	 spritedraw(29,43+(pos*10),44,xorput);
	 if ((pos>0) and (pos<8)) then
	 begin
	    textxy(40,40+(pos*10),4,UIColours[13],keys[pos]);
	    textxy(130,40+(pos*10),4,UIColours[13],keyface(scancode[pos]));
	 end;
      end;
   end;
   {key customisation done - clean up display for settings menu}
   menudone;
   dec(menuDepth);
   startmenu;   
end; { customKeys }

{secret display, memory and sound information screen}
procedure info;
var s,t	: string[50];
    h,y	: integer;
    c	: char;
   tot	: longint;
   col	: byte;
begin
   startmenu;
   { find out memory information (just available at the moment)}
   col := UIColours[9];
   str(memavail,t);
   s := 'Memory Available :' + t;
   textxy(20,10,4,col,s);
   str(maxavail,t);
   s:= 'Largest block :' + t;
   textxy(20,20,4,col,s);

   {print if we are running on a 286}
   if is286 then textxy(190,10,4,col,'286+ processor');

   s := '';
   h := detectGraphics;
   case h of
     1 : s := 'Hercules';
     2 : s := 'CGA';
     3 : begin
	    s:= 'EGA ';
	    case EGAmem of
	      0	: s:= s + '64k';
	      1	: s:= s + '128k';
	      2	: s:= s + '192k';
	      3	: s:= s + '256k';
	    end;
	 end;
     4 : s:= 'VGA';
     5 : s:= 'VESA';
   end;
   s:= 'Graphics card:' + s;
   textxy(180,20,4,col,s);
   
   { find out what sound is detected and being used }
   {$ifndef noAdlib}
   t:=' Using ';
   if isBlaster then t:=t+'Adlib/SoundBlaster' else t:=t+'PC Speaker';
   t:=t+' sound';
   if force=1 then t:='forced PC Speaker';
   if force=2 then t:= 'forced No Sound';
   if force=3 then t:= 'OPL2LPT on LPT1';
   if force=4 then t:= 'OPL2LPT on LPT2';
   {$else}
   t:= ' Using PC Speaker sound';
   {$endif}
   textxy(20,40,4,col,t);

   {display if the joystick is available}
   if joyavail then
      textxy(20,150,4,col,'Joystick found');
   
   {get display information}
   if graphicsMode=mCGA then t:='CGA';
   if graphicsMode=mEGA then t:='EGA';
   if graphicsMode=mVGA then t:='VGA';
   if graphicsMode=mVESA then t:='VESA';
   s:= 'Driver :' + t;
   textxy(20,70,4,col,s);
   case graphicsmode of
     mCGA  : t:= '320x200 4 colours';
     mVGA  : t:= '320x200 256 colours';
     mEGA  : t:= '640x200 16 colours';
     mVESA : t:= '640x400 256 colours';
   end;
   s := 'Mode :' + t;
   textxy(20,80,4,col,s);

   {display the timing information from the engine.}
   str(maxCycle,t);
   s:= 'Max idle cycles :'+t;
   textxy(20,120,4,col,s);
   str(pitRatio,t);
   s:= 'PIT ratio: '+t;
   textxy(20,130,4,col,s);

   if paging then
      if graphicsmode = mEGA then
	 textxy(20,140,4,col,'EGA page flipping enabled')
      else
	 textxy(20,140,4,col,'System memory back-buffer enabled');

   {determine the size and number of sprites}
   str(spriteCount,t);
   s:= 'Sprite Count:'+t;
   textxy(20,160,4,col,s);
   spriteSize(h,y);
   str(h,t);
   s:= 'Sprite size:'+t+'x';
   str(y,t);
   s:=s+t;
   textxy(20,170,4,col,s);
   h:= iSize(h,y);
   tot := h;
   tot := (tot * spriteCount) div 1024;
   str(h,t);
   s:= 'Sprite Mem size:'+t+' total:';
   str(tot,t);
   s:= s+t+'kb';
   textxy(20,180,4,col,s);
   
   {now wait for any key and return to settings screen.}
   while not(keypressed) do checkSongChange;

   while (keypressed) do c:= readkey;

   {clear the display so the settings screen can redraw itself}
   menudone;
   dec(menuDepth);
   startmenu;
end;

procedure spriteTest;
var
   i	      : integer;
   x,y	      : integer;
   c	      : char;
   start,stop : word;
   count,rate : real;
   s	      : string;
   im         : array[0..19] of byte;
begin
   startmenu;
   x := 6; 
   y := 15;
   for i:= 1 to spriteCount do
   begin
      spriteDraw(x,y,i,copyput);
      x := x + 11;
      if (x>=310) then
      begin
	 x:=6;
	 y:=y+11;
      end;
   end;

   for i:=0 to 19 do
      im[i] := i + 1;

   {benchmark the graphics drawing on screen}
   bobgraph.bar(59,179,260,190,UIColours[7]);
   while not(keypressed) do
   begin
      start := timerTick;
      count:=0;
      while ((timerTick< start+(91 * pitRatio)) and not(keypressed)) do
      begin	 
	 for i:= 0 to 19 do
	    spritedraw(60+(i*10),180,im[i],copyput);
	 count := count + 20;
      end;
      stop := timerTick;
      rate := count / (((stop-start) / 18.2) / pitRatio) ;
      for i:= 0 to 19 do
      begin
	 inc(im[i]);
	 if im[i]>spriteCount then im[i]:=1;
      end;
      bobgraph.bar(60,159,200,178,0);
      str(rate:2:2,s);
      s := s + ' Sprites/sec';
      textxy(61,160,4,UIColours[9],s);
   end;

   while (keypressed) do c:= readkey;

   {clear the display so the settings screen can redraw itself}
   menudone;
   dec(menuDepth);
   startmenu;
end;

procedure Settings;
var
    mdone     : boolean;
    a	      : char;
    s	      : byte;
    extt,astt : single;
    t	      : string;
   mem	      : longint;
    pos	      : integer;
   refresh    : boolean;
begin
   startmenu;
   pos:=0;
   s:=gap;
   refresh := true;
   
   mdone:=false;
   while not(mdone) do
   begin
      spritedraw(29,33+((pos)*10),44,copyput);
      if (refresh or (pos=1)) then
      begin
	 if respawn then textxy(40,40,4,UIColours[13],'Monster Respawn')
	 else textxy(40,40,4,UIColours[5],'Monster Respawn');
      end;
      if (refresh or (pos=0)) then
      begin
	 bar(40,32,200,42,0);
	 t:='Speed :';
	 if s=1 then t:=t+'Fast';
	 if s=2 then t:=t+'Normal';
	 if s=4 then t:=t+'Slow';
	 if s=6 then t:=t+'Very Slow';
	 textxy(40,30,4,UIColours[9],t);
      end;
      if (refresh or (pos = 4)) then
	 if soundo then textxy(40,70,4,UIColours[13],'Sound')
	 else textxy(40,70,4,UIColours[5],'Sound');
      if (refresh or (pos = 5)) then
	 if musico then textxy(40,80,4,UIColours[13],'Music')
	 else textxy(40,80,4,UIColours[5],'Music');
      if (refresh or (pos = 2)) then
      begin
	 bar(40,52,200,62,0);
	 t:='Difficulty :';
	 if diff=5 then t:=t+'Easy';
	 if diff=3 then t:=t+'Medium';
	 if diff=1 then t:=t+'Hard';
	 if diff=-3 then t:=t+'InSaNe';
	 textxy(40,50,4,UIColours[9],t);
      end;
      {$ifndef noAdlib}
      if (refresh or (pos=3)) then
      begin
	 if (isBlaster) then
	 begin
	    textxy(40,60,4,UIColours[9],'Volume');
	    volume := getfmVol;
	    bobgraph.bar(100,63,180,73,UIColours[8]);
	    bobgraph.bar(95+(volume*5),63,105+(volume*5),73,UIColours[9]);
	 end
         else textxy(40,60,4,UIColours[5],'Volume Unavailable');
      end;
      {$else}
      if refresh then 
	 textxy(40,60,4,UIColours[5],'Volume Unavailable');
      {$endif}
      if (refresh or (pos = 6)) then
      begin
	 if (joyavail) then
	 begin
	    if (usejoy) then textxy(40,90,4,UIColours[13],'Joystick Available') else
	       textxy(40,90,4,UIColours[5],'Joystick Available');
	 end
         else textxy(40,90,4,UIColours[9],'Joystick Unavailable');
      end;
      if refresh then
      begin
	 textxy(40,100,4,UIColours[9],'Keyboard Control');
	 textxy(40,110,4,UIColours[9],'Hardware Info');
	 textxy(40,120,4,UIColours[9],'Done');
      end;
      refresh := false;
      
      while not(keypressed) do checkSongChange;
      a:=readkey;
      spritedraw(29,33+((pos)*10),44,xorput);


      if (a=chr(13)) then
      begin
	 if pos=9 then mdone:=true;
	 if pos=8 then
	 begin
	    info;
	    refresh := true;
	 end;
	 if pos=7 then
	 begin
	    customKeys;
	    refresh := true;
	 end;
	 if ((pos=6) and joyavail) then
	 begin
	    joycal;
	    refresh := true;
	 end;
      end;
      if (a='S') then
      begin
	 spriteTest;
	 refresh := true;
      end;
      if (a=chr(27)) then mdone:=true;
      if (a=chr(0)) then
      begin
	 a:=readkey;
	 if (a=chr(72)) then dec(pos);
	 if (a=chr(80)) then inc(pos);
	 if (pos=-1) then pos:=9;
	 if (pos=10) then pos:=0;
	 
	 {left key}
	 if (a=chr(75)) then
	 begin
	    if (joyavail and (pos=6)) then
	    begin
	       joycal;
	       refresh := true;
	    end;
	    
	    if (pos=7) then
	    begin
	       customkeys;
	       refresh := true;
	    end;

	    {$ifndef noAdlib}
	    if (isBlaster and (pos=3)) then
	    begin
	       volume:=volume-$02;
	       setfmVol(volume);
	       shoot;        
	    end;
	    {$endif}
	    if (pos=0) then
	    begin
	       if s=6 then s:=1
	       else if s=1 then s:=2
	       else if s=2 then s:=4
	       else if s=4 then s:=6;
	       gap := s;
	    end;
	    
	    if (pos=1) then
	       respawn:=not(respawn);
	    if (pos=2) then
	    begin
	       diff:=diff+2;
	       if diff=-1 then diff:=1;
	       if diff=7 then diff:=-3;
	    end; 
	    
	    if pos=4 then soundo:=not(soundo);
	    if pos=8 then
	    begin
	       info;
	       refresh := true;
	    end;
	    
	    {$ifndef noAdlib}
	    if ((pos=5) and (isBlaster or ((force=3) or (force=4)))) then
	    begin
	       musico:=not(musico);
	       if musico then musicOn else musicoff;
	    end;
	    {$endif}
	 end; {left}
	 {right key}
	 if (a=chr(77)) then
	 begin
	    {if (joyavail and (pos=6)) then
	       usejoy:=not(usejoy);}        
	    if (joyavail and (pos=6)) then
	    begin
	       joycal;
	       refresh := true;
	    end;
	    
	    if (pos=7) then
	    begin
	       customkeys;
	       refresh := true;
	    end;
	    if pos=8 then
	    begin
	       info;
	       refresh := true;
	    end;
	    
	    {$ifndef noAdlib}
	    if (isBlaster and (pos=3)) then
	    begin
	       volume:=volume+$02;
	       setfmVol(volume);
	       shoot;        
	    end;
	    {$endif}
	    
	    if (pos=0) then
	    begin
	       if s=6 then s:=4
	       else if s=4 then s:=2
	       else if s=2 then s:=1
	       else if s=1 then s:=6;
	       gap := s;
	       if s=200 then maxcycle:=10;
	    end;
	    
	    if (pos=1) then
	       respawn:=not(respawn);
	    if (pos=2) then
	    begin
	       diff:=diff-2;
	       if diff=-1 then diff:=-3;
	       if diff=-5 then diff:=5;
	    end; 
	    
	    if pos=4 then soundo:=not(soundo);

	    {$ifndef noAdlib}
	    if ((pos=5) and (isBlaster or ((force=3) or (force=4)))) then
	    begin
	       musico:=not(musico);
	       if musico then musicOn else musicoff;
	    end;
	    {$endif}
	 end;{right}
	 
      end;{special key}
   end; {while}
   menuDone;
end; { Settings }

procedure help;
var pages      : array[1..16,1..5] of string[45];
   icons       : array[1..16,1..5] of word;
    page,x,y,i : integer;
    hdone,new  : boolean;
    a	       : char;
begin
   for i:=1 to 16 do
      for x:= 1 to 5 do icons[i,x]:=0;
   pages[1,1]:='Welcome To Bob`s Fury ...';icons[1,1]:=28;
   pages[2,1]:='';
   pages[3,1]:='Programming: Andrew Danson';icons[3,1]:=59;
   pages[4,1]:='';
   pages[5,1]:='Design and playtesting:';icons[5,1]:=60;
   pages[6,1]:='Benjamin & Andrew Danson';
   pages[7,1]:='';
   pages[8,1]:='PC speaker sound unit:';icons[8,1]:=63;
   pages[9,1]:='J C Kessels ';
   pages[10,1]:='';
   pages[11,1]:='Special Thanks to:';icons[11,1]:=86;
   pages[12,1]:='Sam Baker';
   pages[13,1]:='';
   pages[14,1]:='press PageUp and PageDown';
   pages[15,1]:='for more information or';
   pages[16,1]:='Esc to return';
   pages[1,2]:='How to play...';
   pages[2,2]:='The Keys';
   pages[3,2]:=' Space bar   = fire';icons[3,2]:=47;
   pages[4,2]:=' Up arrow    = jump';
   pages[5,2]:=' left arrow  = move left';
   pages[6,2]:=' right arrow = move right';
   pages[7,2]:=' down arrow  = stop moving';
   pages[8,2]:='     h       = use health bottle';icons[8,2]:=9;
   pages[9,2]:='    Esc      = Menu';
   pages[10,2]:='     g       = fire a grenade';icons[10,2]:=49;
   pages[11,2]:='     p       = pause';
   pages[12,2]:='     n       = change weapon ';icons[12,2]:=50;
   pages[13,2]:='     q       = quit';
   pages[14,2]:='';
   pages[15,2]:='Occasionally you will find blocks that';
   pages[16,2]:='you can shoot, or walk through.';
   pages[1,3]:='Treasures';
   pages[2,3]:='25 points';icons[2,3]:=22;
   pages[3,3]:='50 points';icons[3,3]:=23;
   pages[4,3]:='75 points';icons[4,3]:=24;
   pages[5,3]:='100 points';icons[5,3]:=25;
   pages[6,3]:='125 points';icons[6,3]:=26;
   pages[7,3]:='150 points';icons[7,3]:=27;
   pages[8,3]:='300 points';icons[8,3]:=125;
   pages[9,3]:='Gives you 10 more health ';icons[9,3]:=9;
   pages[10,3]:='Makes you invincible for a short time';icons[10,3]:=10;
   pages[11,3]:=' ';
   pages[12,3]:='The end of the level';icons[12,3]:=21;
   pages[13,3]:='Teleport to another place';icons[13,3]:=84;
   pages[14,3]:='Switch will clear or block a area';icons[14,3]:=85;
   pages[15,3]:='Lightning bolt supply';icons[15,3]:=82;
   pages[16,3]:='Grenade supply';icons[16,3]:=83;
   pages[1,4]:='The Stats part ...';
   pages[2,4]:='  at the bottom of the screen information';
   pages[3,4]:=' about you is shown';
   pages[4,4]:='';
   pages[5,4]:='';
   pages[6,4]:='your score health and number of lives';
   pages[7,4]:='are displayed on the left hand side';
   pages[8,4]:='in the middle there is you inventory of ';
   pages[9,4]:='items you have health bottles, grenades,';
   pages[10,4]:='and lightning bolts.';
   pages[11,4]:='to the right it displays whether you are';
   pages[12,4]:='using the lightning bolts or ordinary';
   pages[13,4]:='bullets';
   pages[14,4]:='';
   pages[15,4]:='';
   pages[16,4]:='';
   pages[1,5]:='Just in case you wanted to know';
   pages[2,5]:=' here is how to use the settings';
   pages[3,5]:=' screen';
   pages[4,5]:='';
   pages[5,5]:='Press up and down to select an';
   pages[6,5]:=' Item and left and right to adjust';
   pages[7,5]:=' the setting.';
   pages[8,5]:='';
   pages[9,5]:=' When calibrating the joystick';
   pages[10,5]:=' pressing the return key returns';
   pages[11,5]:=' to the settings menu.';
   pages[12,5]:='';
   pages[13,5]:='';
   pages[14,5]:='';
   pages[15,5]:='';
   pages[16,5]:='';
   
   page:=1;
   new:=true;
   x:=25;
   y:=5;
   hdone:=false;
   while (not(hdone)) do
   begin
      if new then startmenu;
      new:=false;
      for i:= 1 to 16 do
      begin
	 spritedraw(10,y+(i*10),icons[i,page],copyput);
	 textxy(x,y+(i*10),4,UIColours[9],pages[i,page]);
      end;
      while (not(keypressed))do checkSongChange ;
	 
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
      if new then menuDone;
   end;
   menuDone;
end;

procedure viewScorez; forward;

procedure gamemenu;
var menu:array[1..7] of string[20];
    top,sel:integer;
    x,y:integer;
    mdone:boolean;
    a:char;
begin
   a:=' ';
   mdone:=false;
   startmenu;
   top:=90;
   sel:=1;
   x:=110;
   y:=65;
   menu[1]:='Begin a new game';
   menu[2]:='Save current game';
   menu[3]:='Load a game';
   menu[4]:='Change game settings';
   menu[5]:='Help';
   menu[6]:='View High Scores';
   menu[7]:='Quit Bob`s Fury';
   textxy(x,y,4,UIColours[5],menu[1]);
   textxy(x,y+10,4,UIColours[5],menu[2]);
   textxy(x,y+20,4,UIColours[5],menu[3]);
   textxy(x,y+30,4,UIColours[5],menu[4]);
   textxy(x,y+40,4,UIColours[5],menu[5]);
   textxy(x,y+50,4,UIColours[5],menu[6]);
   textxy(x,y+60,4,UIColours[5],menu[7]);
   while not(mdone) do
   begin
      while not(keypressed) do
      begin
	 checkSongChange;
	 textxy(x,y+((sel-1)*10),4,UIColours[13],menu[sel]);
	 spritedraw(x-11,y+((sel-1)*10)+3,44,copyput);
      end;        {80 is down 72 is up...13 if an enter key}
      a:=readkey;
      if a=chr(27) then mdone:=true;
      if a=chr(13) then
      begin {execute selection}
	 mdone:=true;
	 case sel of
	   1 : begingame;
	   2 : savegame;
	   3 : loadgame;
	   4 : settings;
	   5 : help;
	   6 : viewScorez;
	   7 : begin {quit}
		  player.lives:=0;
		  done:=true;
	       end;
	 end;   
      end;
      if a=chr(0) then
      begin
	 a:=readkey;
	 textxy(x,y+((sel-1)*10),4,UIColours[5],menu[sel]);
	 bobgraph.bar(x-11,y,x-1,y+80,0);
	 if a=chr(72) then sel:=sel-1;
	 if a=chr(80) then sel:=sel+1;
	 if sel=0 then sel:=7;
	 if sel=8 then sel:=1;
      end;
   end;
   menudone;
end;

procedure intro;
var i,c,x,y   : integer;
    a         : char;
   start      : real;
const
   stat : array[1..5,1..30] of byte =(
   (2,0,0,0,0,0,0,0,0,96,0,0,0,0,0,93,0,0,0,0,0,0,0,0,0,0,0,0,0,2),
   (2,0,108,0,0,0,2,2,2,2,0,0,0,0,2,2,2,0,0,0,0,0,0,0,0,51,0,0,0,2),
   (2,0,5,5,0,49,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,2),
   (2,0,0,0,0,0,0,0,0,30,0,0,0,0,0,50,0,0,0,50,0,0,0,0,0,0,50,0,29,2),
   (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2));
begin
   a:=char(1);
   startmenu;
   textxy(30,100,8,UIColours[9],'Bob`s Fury');
   for c:=1 to 5 do
      for i:=1 to 30 do
	 spritedraw((i*10)+5,(c*10)+120,stat[c,i],copyput);
   start := timerTick;
   while (not(keypressed) and ((start+(pitratio*182)>timerTick))) do checkSongChange;
   if keypressed then a:=readkey;
   if a=char(0) then a:=readkey;

   menuDepth:=0;
end;

procedure saveScorez;
var zz:integer;
    buf:array[1..sizeof(score)] of char;
    infile:text;
    i,t:integer;   
begin
	assign(infile,'hiscorez.dat');
	rewrite(infile);
	for i:=0 to 9 do
	begin
		move(scorez[i],buf,sizeof(score));
		for t:=1 to sizeof(score) do
			write(infile,buf[t]);
	end;
	close(infile);
end;

procedure viewScorez;
var i,z,c:integer;
    a:char;
    s:string;
begin
   while (keypressed) do a:=readkey;
   a:=char(0);
   startmenu;
   textxy(130,10,4,UIColours[9],'High Scores');
   textxy(110,20,4,UIColours[9],'press C to clear');
   
   for i:=0 to 9 do
   begin
      str(scorez[i].score,s);
      {z:= 30;
      z:= z-length(scorez[i].name);
      for c := 1 to z do s:=' '+s;
      s:=scorez[i].name +s;}
      c:=15-i;
      if graphicsMode=0 then c:=(c mod 3)+1;
      textxy(50,(i*10) +40 ,4,(c),scorez[i].name);
      textxy(250,(i*10) + 40,4,(c),s);
   end;
   while (not(keypressed)) do checkSongChange;    
   a:=readkey;
   if ((a='c') or (a='C')) then
   begin
      for i:=0 to 9 do
      begin
	 scorez[i].name:='no body';
	 scorez[i].score:=0;             
      end;
      saveScorez;
      viewScorez;
   end;
   menudone;
end;

procedure endGame(score:longint);
var s,z:string;
    i,c:integer;
    done:boolean;
    a:char;
begin
   {now find where the score belongs}
   while (keypressed) do a:=readkey;
   a:=char(0);
   i:=0; done:=false;
   while ( not(done) and (i<10) ) do
   begin
      if (score>scorez[i].score) then 
      begin
	 done:=true;
	 i:=i-1;
      end;
      i:=i+1;                 
   end;
   c:=i;
   if (i=10) then exit;
   startmenu;
   textxy(110,10,4,UIColours[7],'Enter Your Name');
   s:='';
   s:= ginput(s,100,25);
   i:=9;
   while (i>c) do
   begin
      scorez[i] := scorez[i-1];
      i:=i-1;
   end;
   scorez[c].name:=s;
   scorez[c].score:=score;         
   saveScorez;
   viewScorez;
   menudone;
end;

procedure loadScorez;
var zz:integer;
    buf:array[1..sizeof(score)] of char;
    infile:text;
    i,t:integer;   
begin
   if (checkfile('hiscorez.dat')) then
   begin
      assign(infile,'hiscorez.dat');  
      reset(infile);
      for i:=0 to 9 do
      begin
	 for t:=1 to sizeof(score) do
	    read(infile,buf[t]);
	 move(buf,scorez[i],sizeof(score));
      end;
      close(infile);
   end
   else
   begin
      for zz:=0 to 9 do
      begin
	 scorez[zz].name:='no body';
	 scorez[zz].score:=0;            
      end;
   end;
end;


begin
   loadScorez;
   statereset:=false;
   menuDepth :=0;
end.
