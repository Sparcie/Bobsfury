{bob's fury engine A Danson 2000- }
  
unit engine;

 interface
uses moveutil,map,bobgraph,bfont,bsound,fixed,bjoy,keybrd,pitdbl,bsystem,quadtree;
type
   monsterob = object
     x,y,xloc,yloc,power,state:integer;{ on screen location, level location, health level and state machine state variable}
     sd : byte; 	               { Shot delay in ticks}
     typ,frame:byte;                   { monster type and displayed frame }
     direction,displayed:boolean;      { direction it's facing and if it's displayed}
     procedure move;
     function checkhit(i,c,d,fr,bt:integer):boolean;
     function ishit(i,c,fr:integer):boolean;
     constructor make(i,c:integer);
     destructor done;
   end;
     playerrec = record
		    x,y	   : integer; {screen location}
		    score  : longint; {score}
		    invuln : integer; {how much invulerability the player has}
		    health : integer; {health points}
		    lives  : integer; {lives remaining}
		    fullb  : integer; {health bottle items}
		    gren   : integer; {grenades}
		    lbolt  : integer; {lightning bolts}
		    keys   : integer; {bitmap of keys the player has}
		    flyer  : boolean; {is the player transformed!}
		 end;	   
	project = object
		 x,y:integer;
		 dir:byte;
                 typ:byte;
		 hurt:boolean;
		 timeout:integer;
		 constructor make(zx,zy:integer;t, d,h:byte);
		 function move:boolean;
		 end;

 {procedure to draw all bullets after the screen has been erased}
 procedure drawAllBullets;    
 {sets the displayed tag on monsters to false (to prepare for a menu)}  
 procedure hideMonsters;
 {clears all monsters (in preparation for a save or bonus check)}
 procedure clearMonsters;
 {trigger brick explosions (follows chains)}
 procedure brickexplode(x,y:integer);
 {run the game}
 procedure run;
 {check monsters for collision with projectiles}
 function checkmonsters(x,y,d,fr,bt:integer):boolean;
 {new screen (redisplays screen and reinitialises variables)}
 procedure newscreen(iz,lz:integer);
 {load a new level}
 procedure newlevel(path,fle :string);
 {creates a bullet}
 procedure shoot(x,y:integer;t,dir,hurt:byte);
 {draws the player acccording to the information in the player record (using xorput)}
 procedure drawPlayer;
{resets the timing mechanism for if we've been away from the engine for some time}
procedure checkTimer;

 var
    menu	       : boolean; {show menu}
    gap		       : byte;    {tick cycles between gameticks mulitplied by 2}
    lastt,nextt        : word;    {timing related variables}
    done,successful    : boolean; {finished level and finished playing}
    player	       : playerrec; {player record}
    newf	       : integer; {player frame (relative to first one)}
    diff	       : integer; {difficulty level}
    respawn	       : boolean; {monster respawn?}
    freecycle,maxcycle : word;    {idle cycle count}
    useCustomKeys      : boolean; {use the newer keyboard system}
 
implementation

procedure personmove; forward;
procedure preparescreen; forward;
procedure keypress; forward;
procedure joystick; forward;
procedure showscore; forward;
procedure processKeys; forward;
   
var oldplay		 : playerrec; {old player record, used to know what score items to update on status display}
   juf,pdr,pbul,shtt	 : integer;
   {juf= jumping force, pdr = player direction, pbul = player bullet count, shtt = shooting timer }
   creatures		 : array[0..50] of monsterob;
   bullets		 : array[0..50] of project;
   ncreat,nbul		 : integer; {number of creatures and bullets}
   bobhere		 : boolean; {is bob here (is a coss present)}
   firelbolt		 : boolean; {weapon selection between bullets and firebolts}
   oldflbolt		 : boolean; {old copy of firelbolt, for determining if we should update the status display}
   drawstaticstatus	 : boolean; { true if we need to draw the static elements of the status bar }
   boss,bossp		 : integer; {boss picture stuff}
   oldbossp		 : integer; {old version of bossp so we know to update the status display}
   ocw,ohe		 : boolean; {joystick buttons when last updated (so we can see changes)}
   hcount		 : integer; {player hurt timer (0 means you can be hurt, is a number of game ticks)}
   elv			 : byte; {is the player currently on a elevator -  >0 yes, 0 otherwise.}
   rot,rot2,leg,mov,fall : boolean;
   {rot = boolean for tick dividing monsters moving, rot2 = boolean for tick dividing invuln decrementing}
   {leg = boolean to indicate the frame state (legs appart or closed
    mov = whether the player is moving forward or not (control)
    fall = whether the player is falling (control) used to determine if you can jump.}
   visibility		 : byte;
   {the vertical/horizontal distance a monster disappears at - dynamically updated depending on performance - range 75 - 150 }

{checks the timing mechanism and resets it if needed, call when returning from a UI element}
procedure checkTimer;
var
   t : word;
begin
   t := timerTick;
   if abs(t - nextt) > (pitRatio shl 4) then nextt:= t + ((gap * pitRatio) shr 1);
end;

{checks to see if two sprites may be overlaping}
function checkOverlap(x,y,x2,y2 : integer):boolean;
var
   dx,dy : integer;
begin
   checkOverlap:=false;
   dx := abs(x-x2);
   dy := abs(y-y2);
   if ((dx<10) and (dy<10)) then checkOverlap:=true;
end;

function singlekeypress:char;
begin
   while not(keypressed) do checkSongChange;
   singlekeypress := readkey;
end;

procedure pause;
var a : char;
begin
   save(100,0,80,20);
   bobgraph.bar(110,0,170,19,UIColours[9]);
   bobgraph.bar(111,1,169,18,UIColours[1]);
   textxy(120,0,4,UIColours[9],'Paused');
   a:=singlekeypress;
   restore;
   checkTimer;
end; { pause }

procedure quitquestion;
var a : char;
begin
   save(100,0,80,20);
   bobgraph.bar(110,0,170,19,UIColours[9]);
   bobgraph.bar(111,1,169,18,UIColours[1]);
   textxy(120,0,4,UIColours[9],'Quit?');
   a:=singlekeypress;
   a:=upcase(a);
   if ((a='Q') or (a='Y')) then
   begin
      done:=true;
      player.lives:=0;
   end;
   restore;
   checkTimer;
end; { quitquestion }

procedure checkBonus;
var
   mcount, tcount     : integer; {counts of monsters and treasure. }
   oncount, offcount : integer; {count of switches and keyholes used and unused}
   l,s,i,c	     : integer;
   o		     : integer;
   bonus	     : integer;
   am		     : string;
   t		     : word;
begin
   {this is the end of the level so modifications to the level do not matter}
   clearmonsters;
   mcount:=0;
   tcount:=0;
   oncount:=0;
   offcount:=0;
   for l:=0 to getTierCount do
      for s:=1 to 4 do
	 for i:=0 to 30 do
	    for c:=0 to 15 do
	    begin
	       o:=getobjat(i,c,s,l);
	       case o of
		 28,30,32,34,36,38,40,42,43,45,55,57,60,62,64,66,77,121,123,138	: inc(mcount);
		 125,22..27							: inc(tcount);
		 153,154,85							: inc(offcount);
		 155,156,86							: inc(oncount);
	       end;
	    end;
   bonus :=0;
   if (mcount=0) then bonus := bonus + 2000;
   if (tcount=0) then bonus := bonus + 3000;
   if ((oncount>0) and (offcount = 0)) then bonus := bonus + 1000;
   if (diff<3) then bonus := bonus * 2;
   if (diff>3) then bonus := bonus div 2;
   if bonus>0 then
   begin
      bobgraph.bar(90,0,210,22,UIColours[9]);
      bobgraph.bar(91,1,209,21,UIColours[1]);
      textxy(120,1,4,UIColours[9],'BONUS POINTS!');
      str(bonus,am);
      textxy(140,11,4,UIColours[9],am);
      
      l:=250;
      i:=0;
      while i<bonus do
      begin
	 t:= timerTick + (6*pitRatio );
	 while t>timerTick do ;
	 textxy(140,11,4,UIColours[1],am);
	 player.score:=player.score+l;
	 i:=i+l;
	 if keypressed then
	    l:=1000;
	 if (l> bonus-i) then l:= bonus-i;
	 showscore;
	 str(bonus-i,am);
	 textxy(140,11,4,UIColours[9],am);
      end;
   end;
end;

procedure switchTrigger(source :target );
var dest : target;
   o1	 : byte;
begin
   if (isSource(source)) then
   begin
      if gettarget(source,dest) then
      begin
	 if (isSource(dest)) then switchTrigger(dest);
	 o1 := getobjat(dest.x,dest.y,dest.screen,dest.tier);
	 if ( (dest.tier=getTier) and (dest.screen=currentscreen)) then
	    spritedraw(dest.x*10,dest.y*10,o1,xorput);
	 if (o1=0 ) then
	    setobjat(dest.x,dest.y,dest.screen,dest.tier,8)
	 else
	    setobjat(dest.x,dest.y,dest.screen,dest.tier,0);
	 o1 := getobjat(dest.x,dest.y,dest.screen,dest.tier);
	 if ( (dest.tier=gettier) and (dest.screen=currentscreen)) then
	 begin
	    spritedraw(dest.x*10,dest.y*10,o1,xorput);
	    mapp(dest.x*10,dest.y*10);
	 end;
      end;
   end;
end; { switchTrigger }

procedure hurtPlayer(amount : integer);
begin
   if hcount>0 then exit;
   losehealth;
   player.health:=player.health-amount;
   hcount:=5;
end;

procedure pickup(x,y:integer);
var d	       : boolean;
   source,dest : target;
   o	       : byte;
begin
   d:=false;
   o := objectat(x,y);
   if (o<9) then exit; {exit for the common case where no pickup required.}
   case o of
     22	      : 
	 begin
	    gettreasure;
	    d:=true;
	    player.score:=player.score+25;
	 end;
     23	      : 
	 begin
	    gettreasure;
	    d:=true;
	    player.score:=player.score+50;
	 end;
     24	      : 
	 begin
	    gettreasure;
	    d:=true;
	    player.score:=player.score+75;
	 end;
     25	      : 
	 begin
	    gettreasure;
	    d:=true;
	    player.score:=player.score+100;
	 end;
     26	      : 
	 begin
	    gettreasure;
	    d:=true;
	    player.score:=player.score+125;
	 end;
     27	      : 
	 begin
	    gettreasure;
	    d:=true;
	    player.score:=player.score+150;
	 end;
     125      : 
	  begin
	     gettreasure;
	     d:=true;
	     player.score:=player.score+300;
	  end;
     11,12,13 : 
          begin
	     d:=false;
	     hurtPlayer(10);
	  end;
     9	      : 
	       begin
		  if ((player.health =100) and (player.fullb<40)) then
		  begin
		     d:=true;
		     player.fullb:=player.fullb+1;
		     if (player.fullb>19) then
		     begin
			if not(player.lives=10) then
			begin
			   player.lives:=player.lives+1;
			   player.fullb:=player.fullb-20;
			end;
		     end;
		  end;
		  if ((player.health <100)) then
		  begin
		     d:=true;
		     gethealth;
		     player.health:=player.health+10;
		     if player.health>100 then player.health:=100;
		  end;
	       end;
     10	      : 
	       begin
		  invuln;
		  d:=true;
		  player.invuln:=150;
	       end;
     21	      : 
		if (not(bobhere)) then
		begin
		   d:=true;
		   successful:=true;
		   checkBonus;
		end;
     83	      : 
	       begin
		  invuln;
		  d:=true;
		  player.gren:=player.gren+5;
		  if diff < 3 then player.gren := player.gren + 3;
	       end;
     82	      : 
	       begin
		  invuln;
		  d:=true;
		  player.lbolt:=player.lbolt+50;
		  if diff < 3 then player.lbolt := player.lbolt + 20;
	       end;
     84	      : 
	       begin
		  source.x:=x; source.y:=y; source.screen:=currentscreen; source.tier:=gettier;
		  mdis(x*10,y*10);
		  if (gettarget(source,dest)) then
		  begin
		     player.x:=dest.x*10;
		     player.y:=dest.y*10;
		     if not( (currentscreen=dest.screen) and (getTier=dest.tier)) then
		     begin
			newscreen(dest.screen,dest.tier);
		     end;
		     mapp(player.x,player.y);
		  end; 
	       end;
     85	      : 
	       begin
		  spritedraw(x*10,y*10,o,xorput);
		  setobjectat(x,y,86);
		  spritedraw(x*10,y*10,objectat(x,y),xorput);
		  source.x:=x; source.y:=y; source.screen:=currentscreen; source.tier:=gettier; 
		  switchTrigger(source);  
	       end;
     149      : 
	       if (not(player.flyer)) then
	       begin
		  player.flyer:=true;
		  juf:=12;
		  mapp(player.x,player.y);
	       end;
     150      : 
	       if (player.flyer) then
	       begin
		  player.flyer:=false;
		  juf:=0;
		  mapp(player.x,player.y);
	       end;
     151      : 
	       if ((player.keys and $01 = 0)) then
	       begin
		  player.keys := player.keys or $01;
		  d := true;
	       end;
     152      : 
	       if ((player.keys and $02 = 0)) then
	       begin
		  player.keys := player.keys or $02;
		  d := true;
	       end;
     153      : 
	       if ((player.keys and $01 > 0)) then
	       begin
		  player.keys := player.keys and not($01);
		  spritedraw(x*10,y*10,o,xorput);
		  setobjectat(x,y,155);
		  spritedraw(x*10,y*10,objectat(x,y),xorput);
		  source.x:=x; source.y:=y; source.screen:=currentscreen; source.tier:=gettier; 
		  switchTrigger(source);
	       end;
     154      : 
	       if ((player.keys and $02 > 0)) then
	       begin
		  player.keys := player.keys and not($02);
		  spritedraw(x*10,y*10,o,xorput);
		  setobjectat(x,y,156);
		  spritedraw(x*10,y*10,objectat(x,y),xorput);
		  source.x:=x; source.y:=y; source.screen:=currentscreen; source.tier:=gettier; 
		  switchTrigger(source);
	       end;
     160      :
	       begin
		  source.x := 0; source.y:=0; source.screen:=1; source.tier:=0;
		  if (isSource(source)) then deleteTrigger(source);
		  dest.x:=x; dest.y:=y; dest.screen:=currentscreen; dest.tier:=getTier;
		  addTrigger(source,dest);
		  spritedraw(x*10,y*10,o,xorput);
		  setObjectat(x,y,161);
		  spritedraw(x*10,y*10,161,xorput);
	       end;
   end; {end case block}
   
   if d then
   begin
      spritedraw(x*10,y*10,objectat(x,y),xorput);
      setobjectat(x,y,0);
   end;
end;

procedure checkpickup;
begin
   pickup( (player.x+3) div 10,player.y div 10);
   pickup( (player.x+6) div 10,player.y div 10);
end;

procedure showscore;
var s : string[20];
   i  : integer;
begin
   if drawstaticstatus then
   begin
      drawstaticstatus := false;
      textxy(5,165,4,UIColours[7],'Score');
      textxy(5,185,4,UIColours[7],'Lives');
      spritedraw(155,165,9,copyput);
      spritedraw(155,178,49,copyput);
      spritedraw(155,188,50,copyput);
      textxy(250,165,4,UIColours[7],'Weapon');
   end;
   if not(oldplay.score=player.score) then
   begin
      {str(oldplay.score,s);
      textxy(45,165,4,0,s);}
      bar(45,165,90,174,0);
      str(player.score,s);
      textxy(45,165,4,UIColours[7],s);
   end;
   if (not(oldplay.health=player.health) or
       not(player.invuln div 10 = oldplay.invuln div 10)) then
   begin
      {str(oldplay.health,s);
      textxy(45,175,4,0,s);}
      bar(45,175,65,184,0);
      str(player.health,s);
      i:=4;
      if player.health>25 then i:=14;
      if player.health>50 then i:=2;
      if player.health>75 then i:=10;
      i:= UIColours[i];
      if player.invuln>10 then
      begin
	 i:=player.invuln;
	 if player.invuln>100 then i:=31;
	 if player.invuln<100 then
	 begin
	    i:=player.invuln div 10;
	    i:=31-(10-i);
	 end;
      end;
      textxy(5,175,4,i,'Health');
      textxy(45,175,4,i,s);
   end;
   if not(oldplay.lives=player.lives) then
   begin
      {str(oldplay.lives,s);
      textxy(45,185,4,0,s);}
      bar(45,185,50,194,0);
      str(player.lives,s);
      textxy(45,185,4,UIColours[7],s);
   end;
   if not(oldplay.fullb=player.fullb) then
   begin
      {str(oldplay.fullb,s);
      textxy(165,165,4,0,s);}
      bar(165,165,180,174,0);
      str(player.fullb,s);
      textxy(165,165,4,UIColours[7],s);
   end;
   if (not(oldplay.keys=player.keys)) then
   begin
      bobgraph.bar(200,165,220,175,0);
      if (player.keys and $01) > 0 then
	 spritedraw(200,165,151,copyput);
      if (player.keys and $02) > 0 then
	 spritedraw(210,165,152,copyput);
   end;
   if not(oldplay.gren=player.gren) then
   begin
      {str(oldplay.gren,s);
      textxy(165,175,4,0,s);}
      bar(165,175,180,184,0);
      str(player.gren,s);
      textxy(165,175,4,UIColours[7],s);
   end;
   if not(oldplay.lbolt=player.lbolt) then
   begin
      {str(oldplay.lbolt,s);
      textxy(165,185,4,0,s);}
      bar(165,185,185,194,0);
      str(player.lbolt,s);
      textxy(165,185,4,UIColours[7],s);
   end;
   if (oldflbolt xor firelbolt) then 
   begin
      oldflbolt := firelbolt;
      if (firelbolt) then
	 spritedraw(300,167,50,copyput)
      else
	 spritedraw(300,167,47,copyput);
   end;
   if (boss>0) then
   begin
      spritedraw(250,180,boss,copyput);
      if not(oldbossp=bossp) then
      begin
         {str(oldbossp,s);
         textxy(265,180,4,0,s);}
	 bar(265,180,280,189,0);
         str(bossp,s);
         textxy(265,180,4,UIColours[7],s);
         oldbossp:=bossp;
      end;
   end;
   oldplay:=player;
end;

procedure run;
var i: integer;
   z : boolean;
begin
   checkSongChange;
   if keypressed then keypress;
   lastt:=timerTick;
   inc(freecycle);
   if (lastt>=nextt) then
   begin
      if (rot and not(is286)) then
      begin
	 {make some descisions to adjust the visible distance 
          of monsters before disappearing - this is to hopefully reduce slowdown}
	 if ((visibility > 75) and ((freecycle) < 10)) then
	     visibility := visibility - 2;
	 if ((visibility < 150) and (freecycle > 50)) then
	     visibility :=visibility + 2;
	 {line(315,0,315,162,0);
	 line(315,0,315,visibility,1);}
	 {line(316,0,316,162,0);
	 line(316,0,316,lo(freecycle),2);}
      end;
      nextt:=lastt+ ((gap * pitRatio) shr 1);
      if freecycle>maxcycle then maxcycle:=freecycle;
      freecycle:=0;
      rot:=not(rot);
      {move person and use joystick if available}
      if (joyavail and usejoy) then
	 joystick;
      {use custom keys if needed}
      if useCustomKeys then
	 processKeys;
      if hcount>0 then hcount:=hcount-1;
      personmove;
      showscore;
      if shtt>0 then dec(shtt);
      {move monsters}
      if player.invuln>0 then player.health:=100;
      if (rot) then
      begin
	 rot2:=not(rot2);
	 if ((player.invuln>0) and (rot2)) then 
	 begin 
	    dec(player.invuln);
	 end;
	 i:=0;
	 clearTree;
	 while (i<ncreat) do
	 begin
	    creatures[i].move;
	    with creatures[i] do
	       if (displayed) then
		  addMonster(x,y,i);
	    if creatures[i].ishit(player.x,player.y,newf+106) then
	    begin
	       hurtPlayer(5);
	    end;
	    inc(i);
	 end;
	 drawanimations;
      end;
      {move bullets}
      i:=0;
      while (i<nbul) do
      begin
	 z:=bullets[i].move;
	 if not(z) then
	 begin
	    bullets[i]:=bullets[nbul-1];
	    dec(i);
	    dec(nbul);
	 end;
	 inc(i);
      end;
   end;
end;

function checkmonsters(x,y,d,fr,bt:integer):boolean;
var i : integer;
    c : boolean;
   l  : leafptr;
begin
   i:=0;
   c:=false;
{   while ((i<ncreat) and not(c)) do
   begin
      c:=creatures[i].checkhit(x,y,d,fr);
      inc(i);
   end;}
   l := getLeaf(x,y);
   with l^ do begin
      while ((i<count) and not(c)) do
	 begin
	    c:= creatures[id[i]].checkhit(x,y,d,fr,bt);
	    inc(i);
	 end;
   end;
   checkmonsters:=c;
end;

procedure drawAllBullets;
{procedure to draw all bullets after the screen has been erased}
var
   i  : integer;
   fr : integer;
begin
   for i:= 0 to nbul-1 do
   begin
      fr:=0;
      with bullets[i] do
	 begin
	    case typ of
	      0,1 : fr:=47+dir;
	      2	  : fr:=49;
	      3	  : fr:=50;
	    end;
	    spritedraw(x,y,fr,xorput);
	 end;
   end;
end; { drawAllBullets }

procedure hideMonsters; {sets the displayed tag on monsters to false}
var i : integer;
begin
   i:=0;
   while (i<ncreat) do
   begin
      creatures[i].displayed:=false;
      inc(i);
   end;
   oldplay.health:=0; oldplay.lives:=0;oldplay.fullb:=-1;
   oldplay.score:=-1;oldplay.lbolt:=-1;oldplay.gren:=-1;
   drawstaticstatus := true;
   oldflbolt := not(firelbolt);   
end;

procedure clearMonsters;
var i:integer;
begin
   i:=0;
   while (i<ncreat) do
   begin
      creatures[i].done;
      inc(i);
   end;
   ncreat:=0;
end;

function isMonster(ob : byte):boolean;
begin
   isMonster:=false;
   case ob of
     16,28..55,57..78, 116, 121, 123, 138, 142, 147, 157, 166 : isMonster:=true;
   end;
end;

procedure newscreen(iz,lz:integer);
var i,c:integer;
begin
   hcount:=0;
   boss:=0;
   clearanims;
   clearviewport;
   oldplay.health:=0; oldplay.lives:=0;oldplay.fullb:=-1;
   oldplay.score:=-1;oldplay.lbolt:=-1;oldplay.gren:=-1;
   oldplay.keys:=0;
   oldflbolt := not(firelbolt);
   drawstaticstatus := true;
   pbul:=0;
   nbul:=0;
   shtt:=0;
   i:=0;
   while (i<ncreat) do
   begin
      creatures[i].done;
      inc(i);
   end;
   ncreat:=0;
   changescreen(iz);
   if (getspecial) then setTier(lz);
   i:=0;c:=0;
   while (not((i=30) and (c=15))) do
   begin
      if ( isMonster(objectat(i,c)) and (ncreat<51) ) then
      begin
	 creatures[ncreat].power:=0;
	 creatures[ncreat].make(i,c);
	 ncreat:=ncreat+1;
      end;
      inc(i);
      if (i=31) then
      begin
	 i:=0;
	 inc(c);
      end;
   end;
   showscreen;
   checkTimer;
end;

procedure newlevel(path,fle :string);
var i	       : integer;
   source,dest : target;
begin
   i:=0;
   while (i<ncreat) do
   begin
      creatures[i].done;
      i := i+1;
   end;
   hcount:=0;
   ncreat:=0;
   player.x:=0;
   player.y:=0;
   player.keys:=0;
   player.flyer:=false;
   mov:=false;
   pdr:=1;
   newf:=1;
   leg:=false;
   load(path+fle);
   changescreen(1);
   if (getspecial) then setTier(0);
   source.x:=0; source.y:=0; source.screen:=currentscreen; source.tier:=getTier;
   if (gettarget(source,dest)) then
   begin
      player.x:=dest.x*10;
      player.y:=dest.y*10;
      if not( (currentscreen=dest.screen) and (getTier=dest.tier)) then
      begin
	 changescreen(dest.screen);
	 if (getspecial) then setTier(dest.tier);
      end;
   end;
end;

procedure processKeys;
{process the custom key presses}
begin
   mov:=false;
   if pressed(1) then
   begin
      pdr:=0;
      mov:=true;
   end;
   if pressed(2) then
   begin
      pdr:=1;
      mov:=true;
   end;
   if not(player.flyer) then
      if (pressed(4) and (not(fall))) then juf :=10;
   if (pressed(4) and player.flyer) then juf:=6;
   if ((pressed(3)) and (shtt=0)) then
   begin
      if player.lbolt=0 then firelbolt:=false;
      if (not(fireLbolt) and (pbul<5))
	 then shoot(player.x,player.y,0,pdr,0);
      if (firelbolt and (player.lbolt>0)) then
      begin
	 shoot(player.x,player.y,3,pdr,0);
	 player.lbolt:=player.lbolt-1;	 
      end;
   end;
   if (pressed(5)) then
   begin
      clearKey(5);
      firelbolt:=not(firelbolt);
   end;
   if ((pressed(7)) and (player.gren>0) and not(player.flyer)) then
   begin
      clearKey(7);
      shoot(player.x,player.y,2,pdr+3,0);
      player.gren:=player.gren-1;
   end;
   if (pressed(6)) then
   begin
      if ((player.fullb>0) and (player.health<100)) then
      begin
	 clearKey(6);
	 player.fullb:=player.fullb-1;
	 player.health:=player.health+10;
	 if player.health>100 then player.health:=100;
	 gethealth;
      end;
   end;
end; { processKeys }


procedure joystick;
var fi,ju,cw,he : boolean;
begin
   update;
   fi := joypressed(1);
   ju := joypressed(2);
   cw := joypressed(3);
   he := joypressed(4);
   {movement}
   if not(xcentred) then
   begin
      mov:=true;
      pdr:=1;
      if joy.xaxis<joy.xcentre then pdr:=0;
   end
   else
      mov:=false;
   {old jumping method using the y axis
   if not(player.flyer) then
   if (not(ycentred(joy1)) and not(fall)) then juf:=10;
   if (player.flyer and not(ycentred(joy1))) then juf:=6; }
   if not(player.flyer) then
   begin
      if (ju and not(fall)) then juf:=10;
   end
      else if ju then juf:=6;

   {firing your weapon}
   if ((fi) and (shtt=0) and not(cw)) then
   begin
      if player.lbolt=0 then firelbolt:=false;
      if (not(fireLbolt) and (pbul<5 ) ) then shoot(player.x,player.y,0,pdr,0);
      if (firelbolt and (player.lbolt>0)) then
      begin
	 shoot(player.x,player.y,3,pdr,0);
	 player.lbolt:=player.lbolt-1;	 
      end;
   end;

   {change weapon}
   if (cw and (cw xor ocw) and not(fi)) then fireLbolt:=not(fireLbolt);
   {if both cw and fi are pressed you can fire a grenade}
   if (cw and (cw xor ocw) and fi and (player.gren>0) and not(player.flyer)) then 
   begin
      shoot(player.x,player.y,2,pdr+3,0);
      player.gren:=player.gren-1;
   end;
   
   {use health bottle}
   if (he and (he xor ohe)) then
   begin
      if ((player.fullb>0) and (player.health<100)) then
      begin
	 player.fullb:=player.fullb-1;
	 player.health:=player.health+10;
	 if player.health>100 then player.health:=100;
	 gethealth;
      end;
   end;

   ocw := cw;
   ohe := he;
end;

procedure keypress;
var a:char;
begin
   a:=readkey;
   if (a='I') then player.invuln:=300;
   a:= upcase(a);
   if a = 'Q' then quitquestion; {in game quit menu}
   if a = 'P' then pause; {pause game}
   if a=chr(27) then menu:=true;
   if useCustomKeys then
   begin
      if a = chr(0) then a:=readkey;
      exit;
   end;
   if ( (a='H')) then
   begin
      if ((player.fullb>0) and (player.health<100)) then
      begin
	 player.fullb:=player.fullb-1;
	 player.health:=player.health+10;
	 if player.health>100 then player.health:=100;
	 gethealth;
      end;
   end;
   if ((a='G') and (player.gren>0) and not(player.flyer)) then
   begin
      shoot(player.x,player.y,2,pdr+3,0);
      player.gren:=player.gren-1;
   end;
   if (a='N') then firelbolt:=not(firelbolt);
   if ((a = ' ')) then
   begin
      if player.lbolt=0 then firelbolt:=false;
      if (not(fireLbolt) and (pbul<5) and (shtt=0) )
	 then shoot(player.x,player.y,0,pdr,0);
      if (firelbolt and (player.lbolt>0) and (shtt=0)) then
      begin
	 shoot(player.x,player.y,3,pdr,0);
	 player.lbolt:=player.lbolt-1;	 
      end;
   end;
   if a = chr(0) then
   begin {special keys!}
      a:=readkey;
      if not(player.flyer) then
	 if ((a = chr(72)) and (not(fall))) then juf :=10;
      if ((a=chr(72)) and player.flyer) then juf:=6;
	   
      if a=chr(80) then mov :=false;
      if a=chr(75) then begin pdr:=0; mov:=true; end;
      if a=chr(77) then begin pdr:=1; mov:=true; end;
   end;
end;

procedure shoot(x,y:integer;t,dir,hurt:byte);
begin
   if nbul>50 then exit;
   bullets[nbul].make(x,y,t,dir,hurt);
   nbul:=nbul+1;
   if hurt=0 then
   begin
      pbul:=pbul+1;
      shtt:=3;
   end;
end;

constructor project.make(zx,zy:integer;t,d,h:byte);
begin
   if( h=1) then
   begin
      hurt :=true;
   end
   else
   begin
      hurt:=false;
   end;
   x:=zx;
   y:=zy;
   dir:=d;
   typ := t;
   timeout:=40;

   case typ of
     0,1 : begin
	if typ=0 then bsound.shoot else bsound.flyerbomb;
	spritedraw(x,y,47+dir,xorput);
     end;
     2	 : begin
	      bsound.grenade;
	      spritedraw(x,y,49,xorput);
	   end;
     3	 : begin
	      bsound.lbolt;
	      spritedraw(x,y,50,xorput);  
	   end;
   end;
end;

function project.move : boolean;
var mve	 : boolean;
   fr	 : word;
   delta : integer;
   o1    : byte;
begin
   fr:=0;
   mve:=true;
   case typ of
     0,1 : fr:=47+dir; {bullet}
     2	 : fr:=49; {grenade}
     3	 : fr:=50; {lightning bolt}
   end;
   spritedraw(x,y,fr,xorput);
   case dir of
     0 : begin
            delta := moveleft(x+2,y+5,5);
	    x:=x - delta;
	    if (delta < 5) then mve:=false;
	 end;
     1 : begin
     	    delta := moveright(x+8,y+5,5);
	    x:=x + delta;
	    if (delta < 5) then mve:=false;
	 end;
     2 : begin
            delta := movedownw(x+2,y+5,6,5);
	    y:=y + delta;
	    if (delta < 5) then mve:=false;
	 end;
   else
      if dir > 2 then
      begin
	 timeout:=timeout-1;
	 o1 := objectat( (x+2) div 10 , (y+8) div 10 );
	 if ( ((o1 <9) and not(o1 =0)) or (y=150) ) then 
	    y:=y-2 else y:=y+2; 
      end;
     if dir = 3 then
     begin
        delta := moveleft(x,y,2);
	x := x - delta;
	if (delta < 2) then 
	   dir:=4; 			 
     end;
     if dir = 4 then
     begin
        delta := moveright(x+8,y,2);
	x := x + delta;
	if ( delta < 2) then 
	   dir:=3;			 	
     end;
   end;
   
   if (typ=2) then 
   begin
      if (objectat((x+5) div 10,(y+5) div 10))=81 then brickexplode((x+5) div 10,(y+5) div 10);
      if (timeout<1) then
	 mve:=false;
      if not(mve) then
	 begin
	    move:=checkmonsters(x,y,dir,fr,typ);
	    explode(x,y);
	 end;      
   end
   else
   begin {not the grenade}
      o1 := objectat((x+5) div 10,(y+5) div 10);
      if o1=14 then brickexplode((x+5) div 10,(y+5) div 10);
      if ( (o1=80) and (typ=3)) then brickexplode((x+5) div 10,(y+5) div 10);
      if ((x<0) or (x>300) or (y>150)) then mve:=false;
      if not(mve) then bulex(x,y);
   end;

   {check hit player or monster}
   if hurt then
   begin
      {(distance(x,y,player.x,player.y) < 10)}
      if (checkOverlap(x,y,player.x,player.y) and collision(x,y,fr,player.x,player.y,106+newf)) then
      begin
	 delta:=5;
	 if typ =2 then delta:=15;
	 if typ = 3 then delta:=10;
	 hurtPlayer(delta);
	 mve:=false;
      end;
   end
   else {check monster}
      if checkmonsters(x,y,dir,fr,typ) then
      begin
	 mve:=false;
	 if typ=2 then explode(x,y);
      end;

	   
   if (mve) then spritedraw(x,y,fr,xorput);
   if (not(mve) and not(hurt)) then pbul:=pbul-1;
   move:=mve;
end;

procedure brickexplode(x,y:integer);
var
   o : byte;
begin
   if (((x>-1) and (x<31)) and ((y>-1) and (y<16))) then
   begin
      explode(x*10,y*10);
      if objectat(x,y)=8 then exit;
      spritedraw(x*10,y*10,objectat(x,y),xorput);
      o:= objectat(x,y);
      setobjectat(x,y,0);            
      if ((o=14) or (o=80) or (o=81)) then
      begin
	 brickexplode(x-1,y);
	 brickexplode(x+1,y);
	 brickexplode(x,y-1);
	 brickexplode(x,y+1);
      end;
   end;
end;

function crudeDist(x,y,px,py : integer):word;
var
   ax,ay : word;
begin
   ax := abs(x-px);
   ay := abs(y-py);
   crudeDist:=120;
   if ((ax > visibility) or (ay > visibility)) then crudeDist:= 220;
   if ((ax<75) and (ay<75)) then crudeDist:=90;
end;

procedure monsterob.move;
var temp    : boolean;
   olddisp  : boolean; {old display}
   oldframe : byte;    {old frame}
   ox,oy    : integer; {old location}
   prob,res : integer; {shoot probability}
   c	    : byte;    {general use for couting}
   dir, st  : byte;    {shooting direction and type}
   bf,t	    : boolean; {move backwards and forwards (flyers and slugs)}
   ft	    : byte;    {frame type (pointer, flaper, static, bob)} 
   dist     : word;    {distance from player}			   
   source   : target;  {switch trigger target for the bomb creature if it explodes}
   o1,o2    : byte;    {variables to store objectAt queries to reduce the number of them.}
   delta    : integer; { delta for working out distance we can travel }
begin
   {generic first stuff}
   if not((displayed) or (power>0)) then exit;
   olddisp:=displayed;
   oldframe:=frame;
   ox:=x;
   oy:=y;
   temp:=displayed;
   if is286 then
      dist := distance(x,y,player.x,player.y)
   else
      dist := crudeDist(x,y,player.x,player.y);
   {defaults for monsters}
   if dist < 100 then displayed:=true;
   if dist > 200 then displayed:=false;
   prob:=-1; {no shooting}
   dir:=0;   {doesn't matter not shooting}
   st := 0; {standard bullet}
   bf:=true; {moved backwards and forwards}
   ft:=0;    {points like ground creature}

   {decrement the shot delay}
   if sd>0 then dec(sd);

   case typ of {different monster behaviours}
     32	     : 
	 begin
	    prob:=16;
	    dir:=0;
	    st:= 3;
	 end;

     43	     : {tank}
	 begin
	    prob:=12;
	 end;

     42	     : {grenade throwing flyer}
	  begin
	     dir:=3;
	     st := 2;
	     prob:=15;
	     ft:=2;
	  end;

     62	     : {shielded shooter}
	  begin
	     ft:=$FF;
	     frame:=0;
	     if state>0 then inc(state);
	     if state=10 then state:=0;
	     if state>0 then frame:=1;
	     if (state=0) then
	     begin
		res := random(15+diff);
		if res=1 then state:=1;
	     end;
	     if ((state=5) and (displayed) and (power>0)) then
	     begin
		shoot(x,y,0,0,1);
		shoot(x,y,0,1,1);
	     end;
	  end;
     
     35..41:{ordinary flyers}
          begin
	     dir:=2;
	     st:=1;
	     prob:=15;
	     ft:=1;
	  end;

     16	     : {gun turret}
	       begin
		temp:=true;
		displayed:=true;
		bf:=false;
		ft:= $FF; {custom frame}
		prob:= 10;
		if player.x > x then
		begin
		   frame:=1;
		   direction:=true;
		end
	        else
		begin
		   frame:=0;
		   direction:=false;
		end;
	     end;

     138     : {Machine gun turret}
	      begin
		 temp:=true;
		 displayed:=true;
		 bf:=false;
		 ft:= $FF; {custom frame}
		 prob:= 0;
		 if player.x > x then
		 begin
		    frame:=1;
		    direction:=true;
		 end
	         else
		 begin
		    frame:=0;
		    direction:=false;
		 end;
		 if state=1 then
		    if abs(player.y - y) < 40 then state:=30;
		 if state>1 then
		 begin
		    if diff=3 then prob :=5;
		    if diff<3 then prob :=7;
		    if diff>3 then prob :=3;
		    if (30-state) < prob then
		    begin
		       if direction then shoot(x,y,0,1,1);
		       if not(direction) then shoot(x,y,0,0,1);
		    end;
		    dec(state);
		    prob:=0;
		    frame:=frame+2;
		 end;
		 if state<1 then state:=1;
	      end; 
   
     28,45   : {bob's}
              begin
		 boss:=typ+frame;
		 bossp:=power;
		 prob:=8;
		 if dist < 100 then prob:=5;
		 dir:=0;
		 st:=3;
		 if typ=45 then st:=0;
		 displayed:=true;
		 direction:=false;
		 bf:=false;
		 ft:=3;
	      end;

     142     : {crusher}
	      begin
		 temp:=true;
		 bf:=false;
		 ft:=$FF;
		 displayed:=true;
		 inc(state);
		 if state=15 then state:=1;
		 frame:=0;
		 if ((state<6) and (state>0)) then
		    frame:=state-1;
		 if ((state>5) and (state<10)) then
		    frame:=10-state;
	      end;
   
     51	     : {spikes}
	      begin
		 temp:=true;
		 bf:=false;
		 ft:=$FF;
		 displayed:=true;
		 if state=10 then state:=0;
		 if state<6 then
		 begin
		    frame:=2;
		    inc(state);
		 end;
		 if state=6 then
		 begin
		    frame:=2;
		    res := random(10+diff);
		    if ((res=1) and (sd<1))  then
		    begin
		       state:=7;
		       sd := (diff * 2);
		       if diff <0 then sd:=0;
		    end;
		 end;
		 if state=9 then
		 begin
		    frame:=1;
		    state:=10;
		 end;
		 if state=8 then
		 begin
		    frame:=0;
		    state:=9;
		 end;
		 if state=7 then
		 begin
		    frame:=1;
		    state:=8;
		 end;
	      end;

     147     : {drop spike}
	      begin
		 temp:=true;
		 displayed:=true;
		 ft:=2;
		 bf:=false;
		 if ((state=0) and (abs(player.x-x) <30)) then state:=1;
		 if state=1 then
		 begin
		    delta := movedown(x,y+9,4);
		    y := y + delta;
		    if delta<4 then
		    begin
			power:=0;
			displayed:=false;
		    end;
		 end;	
	      end;

     54	     : {grenade dropper}
	      begin
		 temp:=true;
		 displayed:=true;
		 bf:=false;
		 ft:=2;
		 dir:=3;
		 st:=2;
		 prob:=10;
		 if dist>110 then prob:=-1;
		 res:=random(10);
		 if res<5 then direction:=false else direction:=true;
	      end;

     55	     : {bomb creature}
	      begin
		 ft:=$FF;
		 bf:=false;
		 frame:=0;
		 delta := movedownw(x+2,y+9,6,2);
		 y := y + delta;
		 delta := 0;
		 if (x>player.x) then
		     delta:= - movelefth(x,y,9,2);
                 if (x<player.x) then
                     delta := moverighth(x+9,y,9,2);
                 x:= x+ delta;
		 
		 if ((dist < 20) and (power>0)) then
		 begin
		    power:=0;
		    displayed:=false;
		    hurtPlayer(30);
		    explode(x-10,y-10);
		    explode(x,y-10);
		    explode(x+10,y-10);
		    explode(x-10,y);
		    explode(x+10,y);
		    explode(x-10,y+10);
		    explode(x,y+10);
		    explode(x+10,y+10);
		    source.x:=xloc; source.y:=yloc; source.screen:=currentscreen; source.tier:=getTier;
		    switchTrigger(source);
		 end;
	      end;

     57	     : {drop monkey}
	      begin
		 bf:=false;
		 ft:=$FF;
		 frame:=0;
		 if state=0 then
		 begin
		    if ((abs(player.x-x)<20) and (displayed)) then state:=-2;
		 end;
		 if state=-2 then
		 begin
		    frame:=1;
                    delta := movedownw(x+3,y+9,4,2);
                    y := y + delta;
                    if delta < 2 then state := -1;
                    delta:=0;
                    if x>player.x then
                        delta := - movelefth(x,y,9,2);
                    if x<player.x then
                        delta := moverighth(x+9,y,9,2);
                    x:= x + delta;
		 end;
		 if state>0 then
		 begin
		    frame:=1;
                    delta := moveupw(x+2,y,6,state);
                    y:= y - delta;
                    if delta < state then state := -2;
		    dec(state);
		    if state<1 then begin state:= -2; frame:=0; end;
                    delta := 0;
                    if x>player.x then
                        delta := - movelefth(x,y,9,2);
                    if x<player.x then
                        delta := moverighth(x+9,y,9,2);
                    x:= x + delta;
		 end;
		 if state=-1 then
		 begin
		    frame:=2;
		    if ((abs(player.y-y)<35) and displayed) then state:=6;
		 end;    
	      end;

     77	     : {jump boss}
	      begin
		 boss:=typ+frame;
		 bossp:=power;
		 displayed:=true;
		 bf:=false;
		 ft:=$FF;
		 frame:=0;
		 if player.x>x then direction:=true else direction:=false;
		 if state=0 then
		 begin
		    res:=random(9+diff);
		    if res=1 then state:=-3;
		 end;
		 if state=-2 then
		 begin
		    prob:=14;
		    frame:=2;
                    delta := movedownw(x+3,y+9,4,2);
                    y := y + delta;
                    if delta<2 then state := -1;
                    delta:=0;
                    if x>player.x then
                        delta := - movelefth(x,y,9,2);
                    if x<player.x then
                        delta := moverighth(x+9,y,9,2);
                    x:= x + delta;
		 end;
		 if state>0 then
		 begin
		    frame:=2;
		    prob:=14;
                    delta := moveupw(x+2,y,6,state);
                    y:= y - delta;
                    if delta < state then state := -2;
		    dec(state);
		    if state<1 then begin state:= -2; frame:=2; end;
		    delta:=0;
                    if x>player.x then
                        delta := - movelefth(x,y,9,2);
                    if x<player.x then
                        delta := moverighth(x+9,y,9,2);
                    x:= x + delta;
		 end;
		 if state=-1 then
		 begin
		    frame:=1;
		    state:=0;
		 end;
		 if state=-3 then
		 begin
		    frame:=1;
		    state:=10;
		 end;
		 dir:=0;
	      end;
   
     64	     : {roller boss}
	      begin
		 boss:=typ+frame;
		 bossp:=power;
		 displayed:=true;
		 bf:=false;
		 if state=0 then
		 begin
		    if player.x>x then direction:=true else direction:=false;
		    if (abs(player.y-y)<20) then
		       if direction then state:=1 else state:=2;
		 end;
		 if state=1 then
		 begin
                    delta := moverightonfloor(x+9,y,5);
                    x:= x + delta;
                    if delta <5 then state:=0;
		 end;
		 if state=2 then
		 begin
                    delta := moveleftonfloor(x,y,5);
                    x:= x - delta;
                    if delta <5 then state:=0;
		 end;
	      end;

     66	     : {sludge boss}
	      begin
		 boss:=typ+frame;
		 bossp:=power;
		 displayed:=true;
		 bf:=false;
		 ft:=$FF;
		 if ((state>0) and (state<6)) then inc(state);
		 if ((state=0) and (dist<60)) then state:=1;
		 if state>6 then
		 begin
		    inc(state);
		    if state=11 then state:=0;
		 end;
		 if state=6 then
		 begin
		    if power<15 then prob:=5;
		    if player.x>x then direction:=true else direction:=false;
		    delta := 0;
                    if x>player.x then
                        delta := - moveleftonfloor(x,y,2);
                    if x<player.x then
                        delta := moverightonfloor(x+9,y,2);
                    x := x + delta;    
		    dir:=0;
		 end;
		 frame:=state;
	      end;

     116     : {spring board - non lethal not really a monster}
	      begin
		 displayed:=true;
		 temp:=true;
		 bf:=false;
		 ft:=$FF;
		 frame:= 4 - state;
		 if state>0 then dec(state);
		 if (player.y=y) and (abs(player.x-x)<8) then
		 begin
		    state:=4;
		    juf:=14;
		 end;
	      end;

     121,123 : {vertical flying bats that shoot}
              begin
		 ft:=1;
		 bf:=false;
		 prob:=16;
		 st:=0;
		 if typ=121 then st:=3;
		 if player.x>x then
		    direction:=true
		 else
		    direction:=false;
		 if state=0 then
                 begin
                    delta := movedown(x,y+9,2);
                    y := y + delta;
                    if delta<2 then state := 1;
                 end
                 else if state=1 then
                 begin
                    delta := moveup(x,y,2);
                    y := y - delta;
                    if delta<2 then state :=0;
                 end;
	      end;

     157     : {Vertical moving elevator - not really an enemy}
	       begin
		  displayed := true;
		  ft := $FF;
		  frame := frame + 1;
		  if (frame=3) then frame:=0;
		  bf := false;
		  prob:=0;
		  if state=0 then
                 begin
                    delta := movedown(x,y+2,2);
                    y := y + delta;
                    if delta<2 then state := 1;
                 end
		 else if state=1 then
                 begin
                    delta := moveup(x,y-10,2);
                    y := y - delta;
                    if delta<2 then state :=0;
                 end;
		 {ok check to see if the player is in the correct position to use the elevator}
		 if ((player.x <= x+4) and (player.x >= x-4) and (player.y >= y-14) and (player.y<= y-4)) then
		 begin
		    drawPlayer;
		    player.y := y-10;
		    elv := 3;
		    fall:=false;
		    drawPlayer;
		 end;
	       end;
 
     166     : {mummy that walks back and forth}
	       begin
		  ft := 4; {define our own frames!}
		  state := (state + 1) mod 2;
		  if direction then
		     frame := 2 + state
		  else
		     frame := state;
	       end;
   end; {end of monster behaviour case block}
   
   if (bf) then {move backwards and forwards}
   begin
      t:=true;
      case typ of
	30, 32, 34, 43, 55, 60, 62, 166 : t:= false;
      end;
      if yloc = 15 then t:=true;
      if (t) then
      begin
        if not(direction) then
            delta := - moveleft(x,y,2);
        if direction then
            delta := moveright(x+9,y,2);
        x:= x + delta;
        if abs(delta)<2 then direction := not(direction);
      end
      else
      begin
        if not(direction) then
            delta := - moveleftonfloor(x,y,2);
        if direction then
            delta := moverightonfloor(x+9,y,2);
        x:= x + delta;
        if abs(delta)<2 then direction := not(direction);      
      end;
   end;

   if ft=0 then {pointing monster}
     if direction then
      begin
       frame:=1;
      end
      else
      begin
       frame:=0;
      end;

   if ft=1 then {flapping monster}
     if frame=1 then frame:=0 else frame:=1;

   if ((ft=2) or (ft=3)) then frame:=0; {static monster and bob}

   if ((sd<1) and (prob>0) and (power>0) and displayed) then {shoot}
   begin
      res:= random(prob+diff);
      c:=0;
      if direction then c:=1;
      case dir of
	0, 3 : dir:=dir+c;
      end;
      if (res=1) then
      begin
	 shoot(x,y,st,dir,1);
	 if ft=3 then frame:=1;
	 sd := 3;
	 if diff>3 then sd:=5;
      end;
   end;

 {last generic stuff}
   ft:=2;
   if diff<3 then ft:=3;
   if diff>3 then ft:=1;
   if power < 1 then displayed:=false;
   if ((power<1) and (typ=28)) then bobhere:=false;
   if ( ( temp and not(displayed) ) and (power >0) ) then mdis(x,y);
   if ((temp and not(displayed)) and (power <1)) then begin explode(x,y); player.score:=player.score+(5*ft);end;
   if ((displayed and not(temp)) and (power >0)) then mapp(x,y);

   if ( not(ox=x) or not(oy=y) or not(oldframe=frame) or (olddisp xor displayed)) then
   begin
      if olddisp then
      begin
	 spritedraw(ox,oy,typ+oldframe,xorput);
      end;
      if displayed then
      begin
	 spritedraw(x,y,typ+frame,xorput);
      end;
   end;
   
end;

function monsterob.checkhit(i,c,d,fr,bt:integer):boolean;
var source : target;
   r	   : boolean;
   damage  : byte;
begin
   checkhit:=false;
   if not(displayed) then exit;
   if not(checkOverlap(x,y,i,c)) then exit;
   r:=false;
   case typ of
     166,116,142,147,157,51,54 : exit;
     77			   : if state=0 then r:=true;
     66			   : if not(state=6) then exit;
     62			   : if state=0 then r:=true;
     34			   : if not(bt=2) then r:=true;
     36			   : if bt<2 then r:=true;
     40			   : if bt>1 then r:=true;
   end;
   if (r) then
   begin
      checkhit:=true;
      bulex(i,c);
      exit;
   end;
   damage:=1;
   case bt of
     2 : damage:=3;
     3 : damage:=2;
   end;
   if not(collision(i,c,fr,x,y,typ+frame)) then exit;
   if not(typ=60) then
   begin
      power := power - damage;
      if typ=66 then state:=7;
      if power=0 then
      begin
	 xplode;
	 source.x:=xloc; source.y:=yloc; source.screen:=currentscreen; source.tier:=getTier;
	 switchTrigger(source);
	 if typ=55 then
	 begin
	    if distance(x,y,player.x,player.y) < 20 then hurtPlayer(30);
	    explode(x-10,y-10);
	    explode(x,y-10);
	    explode(x+10,y-10);
	    explode(x-10,y);
	    explode(x+10,y);
	    explode(x-10,y+10);
	    explode(x,y+10);
	    explode(x+10,y+10);
	 end;	 
      end;
      checkhit:=true;
   end;
   if (typ=60) then
   begin
      if (direction and (d=1)) then
	 power:=power-damage;
      if (not(direction) and (d=0)) then
	 power:=power-damage;
      if  (not(direction) and (d=1)) then
	 shoot(i,c,0,0,1);
      if  ((direction) and (d=0)) then
	 shoot(i,c,0,1,1);
      if power=0 then
      begin
	 xplode;
	 source.x:=xloc; source.y:=yloc; source.screen:=currentscreen;
	 source.tier:=getTier;
	 switchTrigger(source);
      end;
      checkhit:=true;
   end;
end;

function monsterob.ishit(i,c,fr:integer):boolean;
begin
   ishit:=false;
   case typ of
     116,157 : exit;
     51	     : if state<7 then exit;
     142     : if ((state<2) or (state>9)) then exit;
   end;
   {(distance(x,y,i,c) < 10)}
   if (checkOverlap(x,y,i,c) and (power>0) and collision(i,c,fr,x,y,typ+frame)) then ishit:= true;
end;							 

constructor monsterob.make(i,c:integer);
var z:integer;
    t:boolean;
begin
   state:=0;
   sd := 0;
   displayed:=false;
   typ:=objectat(i,c);
   setobjectat(i,c,0);
   xloc:=i;yloc:=c;
   frame:=0;
   x:=xloc*10;y:=yloc*10;
   power:=3;

   case typ of
     57	      : setobjectat(i,c,56);
     147      : setobjectat(i,c,148);
     142      : state := random(14);
     42,16,60 : power := 6;
     138,57   : power := 10;
     62	      : power := 7;
     55	      : power := 5;
     43	      : power := 9;
     45,66    : power := 40;
     64	      : power := 25;
     77	      : power := 50;
     28	      : begin power := 90; bobhere:=true; end;
   end;

   if diff=-3 then power:=power shl 1;
   if diff=1 then power:= power + (power shr 1);
   if diff>3 then power:=power shr 1;
end;

destructor monsterob.done;
begin
   if respawn then setobjectat(xloc,yloc,typ);
   if power > 0 then setobjectat(xloc,yloc,typ);
   if typ = 28 then bobhere:=false;
end;

procedure drawPlayer;
begin
   if player.flyer then
   begin
      spritedraw(player.x,player.y,121 + (newf mod 2),xorput);
   end
   else
      spritedraw(player.x,player.y,newf+106,xorput);
end;



procedure personmove;
var nx,ny,i,ty : integer;
   source,dest : target;
   a	       : char;
   o1,o2       : byte;
   delta       : integer;
begin
   nx:=0;ny:=0;
   {spritedraw(player.x,player.y,oldf+106,xorput);}
   drawPlayer;
   with player do
   begin
      if juf>0 then
	 begin
	    i:=juf;
	    if juf>8 then
	       i:=i-2;
	    if i>8 then
	    begin
	       delta := moveupw(x+2,y,5,8);
	       if delta=8 then delta := delta + moveupw(x+2,y,5,i-8);
	    end
	    else
	       delta := moveupw(x+2,y,5,i);
	    y := y - delta;

	    if (y and 1) = 1 then inc(y);
	    dec(juf);

	    if (flyer and (juf>6)) then bulex(x,y);
	 end;
      if mov then 
      begin
	 if ((x=300) and (pdr=1) and not(currentscreen = 4)) then
	 begin
	    newscreen(currentscreen+1,getTier);
	    x:=0;
	 end;
	 if ((x=0) and (pdr=0) and not(currentscreen = 1)) then
	  begin
	     newscreen(currentscreen-1,getTier);
	     x:=300;
	  end;
	 delta:=0;
	 if (pdr=0) then delta := - movelefth(x+2,y,9,2);
	 if (pdr=1) then delta := moverighth(x+7,y,9,2);
	 x := x + delta;
	 if x<0 then x:=0;
	 
	 if (not(flyer) and not(delta=0)) then
	 begin
	    leg:=not(leg);
	    newf:=1;
	    if pdr=0 then newf:=3;
	    if leg then inc(newf);
	 end;
      end;
      
      if flyer then
      begin
	 leg:=not(leg);
	 newf:=1;
	 if leg then inc(newf);	    
      end;
      
      if elv=0 then
      begin
	 delta := playerFall(x,y,2);
	 if juf = 0 then y := y + delta;
	 fall := false;
	 if (delta>0) then
	 begin
	    fall:=true;
	    if not(flyer) then leg:=false;
	 end;
      end
      else
	 dec(elv);
      
      if (getspecial) then
      begin
	 i := currentscreen;
	 if ((y=150) and (getTier<getTierCount-1) and (juf=0)) then
	 begin
	    nx := (x+3) div 10;
	    ny := (x+6) div 10;
	    o1 := getobjat(nx,0,i,getTier+1);
	    o2 := getobjat(ny,0,i,getTier+1);
	    if not( ((o1<9) and not(o1=0)) or
		   ((o2<9) and not(o2=0)) ) then
	    begin
	       newscreen(currentscreen,getTier+1);
	       y:=0;
	    end;	 
	 end;         
	 if ((y<=0) and (juf>0) and (getTier>0)) then
	 begin
	    nx := (x+3) div 10;
	    ny := (x+6) div 10;
	    o1 := getobjat(nx,15,i,getTier-1);
	    o2 := getobjat(ny,15,i,getTier-1);
	    if not( ((o1<9) and not(o1=0)) or
		   ((o2 <9) and not(o2=0)) ) then
	    begin
	       newscreen(currentscreen,getTier-1);
	       y:=150;
	    end
	    else y:=0; {limit the movement so we don't fly offscreen!}
	 end;      
      end;
      
   end;
   checkpickup; 
   {spritedraw(player.x,player.y,newf+106,xorput);}
   drawPlayer;
   if (player.health<1) then
   begin
      drawPlayer;
      {spritedraw(player.x,player.y,newf+106,xorput);}
      dec(player.lives);
      player.health:=100;
      i := random(10);
      if player.flyer then
	 i:=6;
      if i>5 then
	 explode(player.x,player.y)
      else
	 disolve(player.x,player.y);
      bsound.xplode;
      nextt:=timerTick + pitRatio;
      while animCount>0 do
      begin
	 while nextt>timerTick do ;
	    nextt:=timerTick + (pitRatio shl 1);
	 drawAnimations;
      end;
      if i<6 then spritedraw(player.x,player.y,135,xorput);
      nextt:=timerTick+ (91*pitratio);
      while ((nextt>timerTick) and not(keypressed)) do ; {wait for a bit!}
	 
      while keypressed do a:=readkey;
      i:=0;
      while (i<ncreat) do
      begin
	  creatures[i].done;
	  inc(i);
      end;
      ncreat:=0;
      player.x:=0;player.y:=0;mov:=false;newf:=1;leg:=false;
      newscreen(1,0);
      source.x:=0; source.y:=0; source.screen:=currentscreen; source.tier:=getTier;
      if (gettarget(source,dest)) then
      begin
	 player.x:=dest.x*10;
	 player.y:=dest.y*10;
	 if not( (currentscreen=dest.screen) and (getTier=dest.tier)) then
	 begin
	    newscreen(dest.screen,dest.tier);
	 end;
      end;
      preparescreen;
    end;
end;

procedure preparescreen;
begin
   showscreen;
   {spritedraw(player.x,player.y,newf+106,xorput);}
   drawPlayer;
   checkTimer;
end;

begin
   bobhere:=false;
   hcount:=0;
   maxcycle:=0;
   freecycle:=0;
   ncreat:=0;
   useCustomKeys:=false;
   juf:=0;
   newf:=1;
   nbul:=0;
   pbul:=0;
   shtt:=0;
   player.x:= 0;
   player.y:= 0;
   player.lives:=3;
   player.score:=0;
   player.health:=100;
   player.invuln:=0;
   player.gren:=0;
   player.lbolt:=0;
   elv := 0;
   respawn:=false;
   pdr:=0;
   lastt:=0;
   nextt:=0;
   randomize;
   pbul:=0;
   successful:=false;
   menu:=false;
   player.fullb:=0;
   firelbolt:=false;
   boss:=0;
   bossp:=0;
   visibility := 150;
   update;  
   calibrate;
end.
