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
        o := objectat((x - dist) div 10, y div 10);
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
        o := objectat((x + dist) div 10, y div 10);
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
        o := objectat(x div 10, (y - dist) div 10);
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
        o := objectat(x div 10, (y + dist) div 10);
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
        o := objectat((x - dist) div 10, y div 10);
        o1 := objectat((x - dist) div 10, (y + h) div 10);
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
        o := objectat((x + dist) div 10, y div 10);
        o1 := objectat((x + dist) div 10, (y + h) div 10);
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
        o := objectat(x div 10, (y - dist) div 10);
        o1 := objectat((x + w) div 10, (y - dist) div 10);
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
        o := objectat(x div 10, (y + dist) div 10);
        o1 := objectat((x + w) div 10, (y + dist) div 10);
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
        o := objectat((x + 2) div 10, (y + 9 + dist) div 10);
        o1 := objectat((x + 7) div 10, (y + 9 + dist) div 10);
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
        o := objectat((x - dist) div 10, y div 10);
        o1 := objectat((x - dist) div 10, (y div 10)+1);
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
        o := objectat((x + dist) div 10, y div 10);
        o1 := objectat((x + dist) div 10, (y div 10)+1);
        if (((o>0) and (o<9)) or ((o1=0) or (o1>8)) or (x+dist>310)) then
            dec(dist)
        else
            done:= true;
        if dist = 0 then done := true; 
    end;
    moverightonfloor := dist;
end;

end.
