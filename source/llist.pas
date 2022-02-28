{Level list for bobsfury - also keeps the description text and name for
 each level}
{A Danson}

unit llist;

interface

type
   leveltext = record
		  data : array[0..16] of string[80];
		  size : integer;
  	       end;    
   leveltextptr	  = ^leveltext;

function ismore:boolean;
procedure startparam(name:string);
procedure nextlevel;
procedure loadepisode(name:string);

function gettext(num : integer; var text:leveltext):boolean;
function getlevel:integer;
function getLevelname:string;
   
var
   nl:integer;
   eppath:string;

implementation 
uses engine,crt,bsystem,buffer,huffdec;

type stringbunch  = array[1..100] of string[80];
   stringbunchptr = ^stringbunch;

   episodetext	  = record
		       data : array[0..100] of leveltextptr;
		       size : integer;
		    end;

var
   param      : boolean;
   no	      : integer;
   levelnames : stringbunchptr;
   levels     : stringbunchptr;
   episode    : episodetext;
   exitsave   : pointer;



function gettext(num : integer; var text:leveltext):boolean;
begin
   gettext:=false;
   if num>episode.size-1 then exit;
   if num<0 then exit;
   gettext:=true;
   text:=episode.data[num]^;
end; { gettext }

function getlevel:integer;
var i : integer;
begin
   i:=no-nl;
   getlevel:=i;
end; { getlevel }

function getLevelname:string;
begin
   getlevelname:=levelnames^[no-nl];
end;
   
function ismore:boolean;
begin
   ismore:=false;
   if nl>0 then ismore:=true;
end;

procedure startparam(name:string);
begin
   newlevel('',name);
   nl:=0;
end;

procedure nextlevel;
var a:char;
begin
   dec(nl);
   newlevel('','.\'+eppath+'\'+levels^[no-nl]+'.map');
   successful:=false;
end;

procedure loadCompressedEpisode(name : string);
var
   dec : decoder;
   cl  : leveltext;
   i   : integer;
   s   : string;
begin
   dec.open('.\'+name+'\episode.huf');
   s := dec.readline;
   no:=0;
   while (not(dec.eof) and not(s[1] = '*')) do
      begin
	 inc(no);
	 if no>100 then no :=1;
	 levelnames^[no] := s;
	 levels^[no] := dec.readline;
	 s:= dec.readline;
      end;
   nl := no;
   
   for i:=0 to episode.size-1 do
      dispose(episode.data[i]);
   episode.size:=0;

   cl.size := 0;
   while (not(dec.eof) and (episode.size<101)) do
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
      new(episode.data[episode.size]);
      episode.data[episode.size]^:=cl;
      inc(episode.size);
      cl.size:=0;
   end;
   dec.close;
   eppath:=name;
end;

procedure loadepisode(name:string);
var infile : reader;
   cl	   : leveltext;
   i	   : integer;
   s	   : string;
begin
   if checkfile('.\'+name+'\episode.huf') then
   begin
      loadCompressedEpisode(name);
      exit;
   end;
  infile.open('.\'+name+'\maps.lst');
  no:=0;
   while not infile.eof do
    begin
       inc(no);
       if no>100 then no:=1;
       levelnames^[no] := infile.readln;
       levels^[no] := infile.readln;
    end;
   infile.close;
   nl:=no;
   for i:=0 to episode.size-1 do
      dispose(episode.data[i]);
   episode.size:=0;
   if checkfile('.\'+name+'\episode.txt') then
   begin    
      infile.open('.\'+name+'\episode.txt');
      episode.size:=0;
      cl.size:=0;
      while (not(infile.eof) and (episode.size<101)) do
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
	 new(episode.data[episode.size]);
	 episode.data[episode.size]^:=cl;
	 inc(episode.size);
	 cl.size:=0;
      end;
      infile.close;
   end;
  
  eppath:=name;
end;

{$F+}
procedure newexitproc;
var i : integer;
begin
   exitproc:=exitsave;
   dispose(levels);
   dispose(levelnames);
   for i:=0 to episode.size-1 do
      dispose(episode.data[i]);
   episode.size:=0;
end;
{$F-}

begin
   new(levels);
   new(levelnames);
   episode.size:=0;
   exitsave:=exitproc;
   exitproc:=@newExitProc;
   nl:=0;
   no:=0;
end.
