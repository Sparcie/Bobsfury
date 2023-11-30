program bob;  {this is almost Bob's fury yah!}
{compiler directives }
{$R-} {range checking off}
{$S-} {stack checking off}
{ G } {80286 instructions (disabled in hope of getting it to run on an XT }

{ remove using math co-pro as it was causing issues in interrupts.}

{$M 16384,0,655360} {memory}

uses bobgraph, bfont,engine,bsound,bconfig,bmenu,llist,map,pitdbl,bsystem;

var
   avail,min : longint;
   startmap  : boolean;
   usepitdbl    : boolean;

procedure param(s,s2 : String);
begin
   {$ifndef CGA}
   if s= '-h' then graphicsMode:=3;
   if s= '-l' then graphicsMode:=2;
   if s= '-e' then graphicsMode:=1;
   if s= '-cga' then graphicsMode:=0;
   {$endif}

   {$ifndef noAdlib}
   if s= '-a' then force:=0;
   if s= '-s' then force:=1;
   if s= '-n' then force:=2;
   if s = 'LPT1' then force:=3;
   if s = 'LPT2' then force:=4;
   {$endif}
   
   if s= '-np' then usepitdbl := false;
   if s= '-c' then
   begin
      player.lives:=3;
      startmap:=true;
      startparam(s2);
   end;
   if ((s= '?') or (s='/?')) then
   begin
      {$ifndef XT}
      writeln('Bobs fury');
      {$else}
      writeln('XT Bobs fury');
      {$endif}
      writeln('command line options:');
      {$ifndef CGA}
      writeln(' -h     hi resolution mode');
      writeln(' -l     lo resolution mode');
      writeln(' -e     EGA graphics mode');
      writeln(' -cga   CGA graphics mode');
      {$endif}
      {$ifndef noAdlib}
      writeln(' -a     autodetect sound');
      writeln(' -s     force sound to use PC speaker');
      writeln(' -n     force sound off');
      writeln(' LPT1   use OPL2LPT on LPT1');
      writeln(' LPT2   use OPL2LPT on LPT2');
      {$endif}
      writeln(' -np    disable doubling pit speed');
      writeln(' -c <filename.map>  load a custom level');
      writeln;
      halt(0);
   end;
end;

procedure levelover;
var txt	: leveltextptr;
begin
   new(txt);
   nextlevel;
   if gettext(llist.getlevel,txt^) then doleveltext(getlevelname,txt^)
   else
      leveltitle(getlevelname);
   dispose(txt);
end;

begin
   usepitdbl:=true;
   avail := memavail;
   writeln('loading conf');
   getconf; {check params}
   startmap:=false;

   player.lives:=0;
   param(paramstr(1),paramstr(2));
   param(paramstr(2),paramstr(3));
   param(paramstr(3),paramstr(4));
   param(paramstr(4),paramstr(5));

   writeln('memory:',avail);
   writeln('setting pitdbl:',usepitdbl);
   if usepitdbl then enablePitDbl(2);
   writeln('loading font');
   loadfont('litt.chr');
   writeln('starting sound');
   initSound;
   writeln('starting graphics');
   startgraphics;
 
   min:=memavail;
   
   done:=false;
   intro;
   if startmap then
   begin
      engine.newscreen(currentscreen,getTier);
      drawplayer;
   end;
   while not(done) do {program loop}
   begin
      
      if (not(successful) and (player.lives=0)) then gamemenu;
      
      {game loop}
      while ((player.lives>0) and not(successful)) do
      begin
	 run;
	 if menu then
	 begin
	    if memavail<min then min:=memavail;
	    gamemenu;
	    menu:=false;
	 end;
      end;
      if memavail<min then min:=memavail;
      if ( not(done) and (player.score>0) and not(successful)) then
      begin
	 endGame(player.score);
	 player.score:=0;
	 gamemenu;
      end; 
      if (ismore and successful) then levelover;
      if (not(ismore) and successful) then
      begin
	 {going to insert little ended episode thingy here!}
	 endGame(player.score);
	 player.score:=0;
	 gamemenu;
      end;
   end;
   finish;
   saveconf;
   disposeFont;
   min:= avail - min;
   if isBlaster then writeln('Adlib/SoundBlaster detected');
   if force=3 then writeln('OPL2LPT on LPT1');
   if force=4 then writeln('OPL2LPT on LPT2');
   writeln('Memory details...');
   write('memory available after load ');
   writeln(avail);
   write('heap used ');
   writeln(min);
   write('Max free cycles ');
   writeln(maxcycle);
   write('Graphics detected ');
   case detectGraphics of
     5 : writeln('VESA');
     4 : writeln('VGA');
     3 : writeln('EGA');
     2 : writeln('CGA');
     1 : writeln('Hercules');
   end;
end.
