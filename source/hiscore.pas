{ Hi score table storage unit - so we can store a separate highscore
  table for each episode as each has a different theoretical maximum score
  A Danson 2026 }

unit hiscore;

interface

{Data type for a score table and a pointer to one}
type
   scoreTable = record
		   episode : string[25];
		   eppath  : string[8];  { the path for the episode }
		   name	   : array[0..9] of string[30];
		   scorez  : array[0..9] of longint;
		end;	   
   tableptr   = ^scoreTable;

var
   tableCount : byte;

function currentScoreTable:tableptr; {get table index for current episode}
function indexScoreTable(i : byte) :tableptr; {get a specific table by index}

procedure loadScores; {load the high scores from disk}
procedure saveScores; {save the high scores to disk}

implementation

uses llist, bsystem;

var
   tables : array[0..29] of tableptr;

function newTable( path, ename : string):tableptr;
var
   nTable : tableptr;
   i	    : byte;
begin
   new(nTable);
   with nTable^ do
   begin
      eppath := path;
      episode := ename;
      for i:= 0 to 9 do
      begin
	 name[i] := 'nobody';
	 scorez[i] := 0;
      end;
   end;
   newTable := nTable;
end;
				    
function currentScoreTable:tableptr;
var
   i : byte;
begin
   for i:= 0 to tableCount -1 do
      if ( llist.eppath = tables[i]^.eppath) then
      begin
	 currentScoreTable := tables[i];
	 exit;
      end;
   {if we get here we need a new table!}
   tables[tableCount] := newTable(llist.eppath, llist.epname);
   currentScoreTable := tables[tableCount];
   inc(tableCount);
end;

function indexScoreTable(i : byte) :tableptr;
begin
   indexScoreTable := tables[i];
end;

procedure loadScores;
var
   scoreFile : file;
   read	     : word;
begin
   if not( checkFile('hiscorez.dat')) then exit;
   if (tableCount>0) then exit;
   assign(scoreFile, 'hiscorez.dat');
   reset(scoreFile, 1);
   { read score tables until there are no more to read }
   while not(eof(scoreFile)) do
   begin
      new(tables[tableCount]);
      blockread(scoreFile, tables[tableCount]^, sizeOf(scoreTable), read);
      inc(tableCount);
   end;
   close(scoreFile);
end;

procedure saveScores;
var
   scoreFile : file;
   write     : word;
   i	     : byte;
begin
   if not(canWriteTo('hiscorez.dat')) then exit;
   if tableCount = 0 then exit;
   assign(scoreFile, 'hiscorez.dat');
   rewrite(scoreFile,1);
   for i:= 0 to tableCount-1 do
   begin
      blockwrite(scoreFile, tables[i]^, sizeof(scoreTable), write);
   end;
   close(scoreFile);
end;
   
begin
   tableCount := 0;
end.
