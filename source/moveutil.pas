{ movement utility library for bobsfury
  A Danson 2022
  
  This unit is for simplifying the game logic in engine.pas
  by providing some basic movement code that can be reused
  for all moving enitities. Some of that old logic is crusty and
  needs replacing to make things smaller, faster and easier to
  understand}

unit moveutil;

interface

{each move function takes the leading edge as input (in x,y) and returns the distance that can be travelled
 without running into a wall } 
function moveleft(x,y,dist : integer):integer;
function moveright(x,y,dist : integer):integer;
function moveup(x,y,dist : integer):integer;
function movedown(x,y,dist : integer):integer;

{each move function takes the leading edge as input (in x,y) and returns the distance that can be travelled
 without running into a wall, these test with a width/height } 
function movelefth(x,y,h,dist : integer):integer;
function moverighth(x,y,h,dist : integer):integer;
function moveupw(x,y,w,dist : integer):integer;
function movedownw(x,y,w,dist : integer):integer;

{this one is specific to the player who can also land on block 15}
function playerfall(x,y,dist: integer):integer;

{ these functions are specific to enemies that walk on a surface }
function moveleftonfloor(x,y,dist : integer):integer;
function moverightonfloor(x,y,dist : integer):integer;

{look-up tables for multiply and divide - just for screen co-ordinates}
var
   divLookup : array[0..320] of byte; {only need bytes as nothing over 32}
   mulLookup : array[0..32] of word; {need words - maximum value 320}

implementation

uses map;

function moveleft(x,y,dist : integer):integer;
var
    done : boolean;
    o: byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x - dist], divLookup[y]);
        if ((o>0) and (o<9)) or (x-dist < 0) then
            dec(dist)
        else
            done:= true;
        if dist = 0 then done := true; 
    end;
    moveleft := dist;
end;

function moveright(x,y,dist : integer):integer;
var
    done : boolean;
    o : byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x + dist], divLookup[y]);
        if ((o>0) and (o<9)) or (x+dist > 310) then
            dec(dist)
        else
            done:= true; 
        if dist = 0 then done:=true;
    end;
    moveright := dist;
end;

function moveup(x,y,dist : integer):integer;
var
    done : boolean;
    o : byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x], divLookup[y - dist]);
        if ((o>0) and (o<9)) or (y-dist <0) then
            dec(dist)
        else
            done:= true; 
        if dist = 0 then done:=true;
    end;
    moveup := dist;
end;

function movedown(x,y,dist : integer):integer;
var
    done : boolean;
    o : byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x], divLookup[y + dist]);
        if ((o>0) and (o<9)) or (y+dist>160) then
            dec(dist)
        else
            done:= true; 
        if dist = 0 then done:=true;
    end;
    movedown := dist;
end;


function movelefth(x,y,h,dist : integer):integer;
var
    done : boolean;
    o, o1: byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x - dist], divLookup[y]);
        o1 := objectat(divLookup[x - dist], divLookup[y + h]);
        if (((o>0) and (o<9)) or ((o1>0) and (o1<9)) or (x-dist<0)) then
            dec(dist)
        else
            done:= true;
        if dist = 0 then done := true; 
    end;
    movelefth := dist;
end;

function moverighth(x,y,h,dist : integer):integer;
var
    done : boolean;
    o, o1: byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x + dist], divLookup[y]);
        o1 := objectat(divLookup[x + dist], divLookup[y + h]);
        if (((o>0) and (o<9)) or ((o1>0) and (o1<9)) or (x+dist>310)) then
            dec(dist)
        else
            done:= true; 
        if dist = 0 then done:=true;
    end;
    moverighth := dist;
end;

function moveupw(x,y,w,dist : integer):integer;
var
    done : boolean;
    o, o1: byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x], divLookup[y - dist]);
        o1 := objectat(divLookup[x + w], divLookup[y - dist]);
        if (((o>0) and (o<9)) or ((o1>0) and (o1<9)) or (y-dist<0)) then
            dec(dist)
        else
            done:= true; 
        if dist = 0 then done:=true;
    end;
    moveupw := dist;
end;

function movedownw(x,y,w,dist : integer):integer;
var
    done : boolean;
    o, o1: byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x], divLookup[y + dist]);
        o1 := objectat(divLookup[x + w], divLookup[y + dist]);
        if (((o>0) and (o<9)) or ((o1>0) and (o1<9)) or (y+dist>160)) then
            dec(dist)
        else
            done:= true; 
        if dist = 0 then done:=true;
    end;
    movedownw := dist;
end;

function playerfall(x,y,dist: integer):integer;
var
    done : boolean;
    o, o1: byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x + 2], divLookup[y + 9 + dist]);
        o1 := objectat(divLookup[x + 7], divLookup[y + 9 + dist]);
        if (((o>0) and (o<9)) or ((o1>0) and (o1<9)) or (o=15) or (o1=15) or (y+dist>160)) then
            dec(dist)
        else
            done:= true; 
        if dist = 0 then done:=true;
    end;
    playerfall := dist;
end;


function moveleftonfloor(x,y,dist : integer):integer;
var
    done : boolean;
    o, o1: byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x - dist], divLookup[y]);
        o1 := objectat(divLookup[x - dist], divLookup[y]+1);
        if (((o>0) and (o<9)) or ((o1=0) or (o1>8)) or (x-dist<0)) then
            dec(dist)
        else
            done:= true;
        if dist = 0 then done := true; 
    end;
    moveleftonfloor := dist;
end;

function moverightonfloor(x,y,dist : integer):integer;
var
    done : boolean;
    o, o1: byte;
begin
    done:=false;
    while not(done) do
    begin
        o := objectat(divLookup[x + dist], divLookup[y]);
        o1 := objectat(divLookup[x + dist], divLookup[y]+1);
        if (((o>0) and (o<9)) or ((o1=0) or (o1>8)) or (x+dist>310)) then
            dec(dist)
        else
            done:= true;
        if dist = 0 then done := true; 
    end;
    moverightonfloor := dist;
end;

procedure fillTables;
var i : word;
begin
   for i:= 0 to 320 do
      divLookup[i] := i div 10;
   for i:= 0 to 32 do
      mulLookup[i] := i * 10;
end;

begin
   fillTables;
end.
