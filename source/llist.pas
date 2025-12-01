{Level list for bobsfury - also keeps the description text and name for
 each level}
{A Danson}

unit llist;

interface

type
   leveltext = record
		  data : array[0..16] of string[60];
		  size : integer;
  	       end;    
   leveltextptr	  = ^leveltext;

function ismore:boolean;
procedure startparam(name:string);
procedure nextlevel;
procedure loadepisode(name:string);

function gettext(num : integer; var text:leveltext):boolean;
function getlevel:integer;
procedure setlevel(l: integer);
function getLevelname	: string;
   
var
   eppath : string[8];
   epname : string[25];

implementation 
uses engine,bsystem,buffer,huffdec;

type
   level = record
	      name     : string[60];
	      mapfile  : string[12];
	     end;      
   levelptr = ^level;
   
   episodedata	  = record
		       data	 : array[1..50] of levelptr;
		       story	 : array[0..51] of leveltextptr;
		       size	 : integer;
		       storysize : integer;
		    end;	 
   episodeptr = ^episodedata;

var
   param    : boolean; 
   current  : integer;
   episode  : episodeptr;
   exitsave : pointer;
   loaded   : boolean;

procedure unload; {unloads a currently loaded episode}
var
   i : integer;
begin
   if not(loaded) then exit;
   {free all the episodes and episode texts}
   with episode^ do
   begin
      for i:= 1 to size do
      begin
	 dispose(data[i]);
      end;
      for i:= 0 to storysize-1 do
      begin
	 dispose(story[i]);
      end;
   end;
   dispose(episode);
   loaded := false;
end;
   

function gettext(num : integer; var text:leveltext):boolean;
begin
   if not(loaded) then exit;
   gettext:=false;
   if num>=episode^.storysize then exit;
   if num<0 then exit;
   gettext:=true;
   text :=episode^.story[num]^;
end; { gettext }

procedure setlevel(l: integer);
begin
   current := l;
end;

function getlevel:integer;
begin
   getlevel:=current;
end; { getlevel }

function getLevelname:string;
begin
   getLevelname:= '';
   if not(loaded) then exit;
   if ((current<1) or (current>episode^.size)) then exit;
   getlevelname:=episode^.data[current]^.name;
end;
   
function ismore:boolean;
begin
   ismore:=false;
   if not(loaded) then exit;
   if current<episode^.size then ismore:=true;
end;

procedure startparam(name:string);
begin
   newlevel('',name);
   current:=0;
   loaded:=false;
end;

procedure nextlevel;
begin
   if not(loaded) then exit;
   inc(current);
   with episode^ do
      with data[current]^ do
	 newlevel('','.\'+eppath+'\'+ mapfile +'.map');
   successful:=false;
end;

procedure loadCompressedEpisode(name : string);
var
   dec	  : decoder;
   cl	  : leveltext;
   i	  : integer;
   s	  : string;
   lcount : integer;
begin
   unload;
   new(episode);
   with episode^ do
   begin
      dec.open('.\'+name+'\episode.huf');
      s := dec.readline;
      lcount:=0;
      while (not(dec.eof) and not(s[1] = '*')) do
      begin
	 inc(lcount);
	 if lcount>50 then lcount :=50;
	 new(data[lcount]);
	 with data[lcount]^ do
	 begin
	    name := s;
	    mapfile := dec.readline;
	 end;
	 s:= dec.readline;
      end;
      size := lcount;
   
      storysize := 0;
      cl.size := 0;
      while (not(dec.eof) and (storysize<52)) do
      begin
	 i:=0;
	 while (not(dec.eof) and (i=0) and (cl.size<17)) do
	 begin
	    s:= dec.readline;
	    if not(s[1]='*') then
	    begin
	       cl.data[cl.size]:=s;
	       inc(cl.size);
	    end
	    else
	    begin
	       i:=1;
	    end;	    
	 end;
	 new(story[storysize]);
	 story[storysize]^:=cl;
	 inc(storysize);
	 cl.size:=0;
      end;
      dec.close;
      eppath:=name;
      loaded := true;
      current:=0;
   end;
end;

procedure loadepisode(name:string);
var infile : reader;
   cl	   : leveltext;
   i	   : integer;
   s	   : string;
   lcount  : integer;
begin
   if checkfile('.\'+name+'\episode.huf') then
   begin
      loadCompressedEpisode(name);
      exit;
   end;
   unload;
   new(episode);
   with episode^ do
   begin
      infile.open('.\'+name+'\maps.lst');
      lcount:=0;
      while not infile.eof do
      begin
	 inc(lcount);
	 if lcount>50 then lcount:=50;
	 new(data[lcount]);
	 with data[lcount]^ do
	 begin
	    name := infile.readln;
	    mapfile := infile.readln;
	 end;
      end;
      infile.close;
      size:=lcount;
      
      storysize:=0;
      if checkfile('.\'+name+'\episode.txt') then
      begin    
	 infile.open('.\'+name+'\episode.txt');
	 cl.size:=0;
	 while (not(infile.eof) and (storysize<52)) do
	 begin
	    i:=0;
	    while (not(infile.eof) and (i=0) and (cl.size<17)) do
	    begin
	       s:= infile.readln;
	       if not(s[1]='*') then
	       begin
		  cl.data[cl.size]:=s;
		  inc(cl.size);
	       end
	       else
	       begin
		  i:=1;
	       end;	    
	    end;
	    new(story[storysize]);
	    story[storysize]^:=cl;
	    inc(storysize);
	    cl.size:=0;
	 end;
	 infile.close;
      end;  
      eppath:=name;
      loaded := true;
      current:=0;
   end;
end;

{$F+}
procedure newexitproc;
begin
   exitproc:=exitsave;
   unload;
end;
{$F-}

begin
   exitsave:=exitproc;
   exitproc:=@newExitProc;
   loaded := false;
   param := false;
   current := 0;
end.
