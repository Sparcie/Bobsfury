{ Simple static Quadtree for reducing the load on collision detection for monsters}
{ A Danson 2021 }

unit quadtree;

interface

type
   leaf	   = record 
		id: array[0 .. 20] of byte;
		count : byte;
	     end;     
   leafptr =  ^leaf;

procedure addMonster(mx,my : integer; i:byte);
procedure clearTree;
function getLeaf(x,y: integer ): leafptr;


implementation


type
   node =  record 
	      areas:array[0..3] of leaf; {in order topLeft, topRight, bottomLeft, bottomRight}	 
	      midX,midy	: integer; {middle of this area in x and y co-ords}
	   end;		
   root =  record
	      areas : array[0..3] of node; {in order topLeft, topRight, bottomLeft, bottomRight}
	      {range is 0-300 for x, and 0-150 for y}
	   end;

var
   qTree : root;

function quad(cx,cy,tx,ty :integer ):byte; {simple function to determine which quadrant a target is in.}
begin
   quad:=0; {top left is default case}
   if ((cx>tx) and (cy<=ty)) then quad:=2;
   if ((cx<=tx) and (cy<=ty)) then quad:=3;
   if ((cx<=tx) and (cy>ty)) then quad:=1;
end;

procedure addToLeaf(n, l, i:byte);
begin
   with qTree.areas[n].areas[l] do
      begin
	 if count=20 then exit;
	 id[count]:=i;
	 inc(count);
      end;
end;

procedure addToNode(mx,my :integer; i,n : byte);
var
   ax,ay : integer;
   q,nq	 : byte;
begin
   with qtree.areas[n] do
      begin
	 q := quad(midX,midY,mx,my);
	 addToLeaf(n,q,i);
	 ax := abs(midX-mx);
	 ay := abs(midY-my);
	 if (ax<10) then
	    begin
	       nq:= quad(midX,midY,mx+10,my);
	       if nq<>q then addToLeaf(n,nq,i);
	    end;
	 if (ay<10) then
	    begin
	       nq:= quad(midX,midY,mx,my+10);
	       if nq<>q then addToLeaf(n,nq,i);
	    end;
	 if ((ax<10) and (ay<10)) then
	    begin
	       nq:= quad(midX,midY,mx+10,my+10);
	       if nq<>q then addToLeaf(n,nq,i);
	    end;
      end;
end;

procedure addMonster(mx,my : integer; i:byte); {add a monster to the appropriate part of the tree}
var
   ax,ay : integer;
   q,nq	 : byte;
begin
   q := quad(150,75,mx,my);
   addToNode(mx,my,i,q);
   ax := abs(150-mx);
   ay := abs(75-my);
   if (ax<10) then
   begin
      nq:= quad(150,75,mx+10,my);
      if nq<>q then addToNode(mx,my,i,nq);
   end;
   if (ay<10) then
   begin
      nq:= quad(150,75,mx,my+10);
      if nq<>q then addToNode(mx,my,i,nq);
   end;
   if ((ax<10) and (ay<10)) then
   begin
      nq:= quad(150,75,mx+10,my+10);
      if nq<>q then addToNode(mx,my,i,nq);
   end;
end;

procedure clearTree;
var
   i,c : byte;
begin
   for i:=0 to 3 do
      for c:=0 to 3 do
	 qtree.areas[i].areas[c].count:=0;
end;


function getLeaf(x,y :integer ):leafptr;
begin
   with qTree.areas[quad(150,75,x,y)] do
      begin
	 getLeaf := addr(areas[quad(midX,midY,x,y)]);
      end;   
end;


begin
   {set up the mid points for all the nodes}
   with qTree do
      begin
	 areas[0].midX := 75; {top Left}
	 areas[0].midY := 37;
	 areas[1].midX := 225; {top right}
	 areas[1].midY := 37;
	 areas[2].midX := 75; {bottom left}
	 areas[2].midY := 112;
	 areas[3].midX := 225; {bottom right}
	 areas[3].midY := 112;	 
      end;
end.
