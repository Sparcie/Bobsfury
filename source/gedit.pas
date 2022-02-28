program gedit;
{$M 65520,0,655360}
{$G+}

uses images,vgavesa,crt,graph,dos;

const mx=320;
	  my=200;

var temp	  : bitmap;
	img	  : bitmap;
	x,y,sx,sy : integer;
	cc,lc	  : word;
        fx,fy	  : integer;
	t	  : string;
	cd,rf	  : boolean;

procedure init;
var i,c:integer;
	s:string;
begin
   randomize;
   writeln('pick a size for the x axis');
   readln(s);
   val(s,i,c);
   while ((not(c=0) or (i=0)) or (i>mx) ) do
   begin
      writeln('invalid input please reenter');
      readln(s);
      val(s,i,c);
   end;
   sx:=i;
   writeln('pick a size for the y axis');
   readln(s);
   val(s,i,c);
   while ((not(c=0) or (i=0)) or (i>my) ) do
   begin
      writeln('invalid input please reenter');
      readln(s);
      val(s,i,c);
   end;
   sy:=i;
   writeln(sx,sy);
   vga256(0);
   settextstyle(smallfont,horizdir,4);
   cc:=0;x:=0;y:=0;lc:=0;cd:=false;
   clearviewport;
end;

procedure done;
begin
   closevid;
end;

function ginput(x,y:integer):string;
var z,s	     : string;
	done : boolean;
	a    : char;
   i	     : integer;
begin
   z:='';
   done:=false;
   while not(done) do
   begin
      while not(keypressed) do;
      a:=readkey;
      setcolor(0);
      s:=z+'_';
      outtextxy(x,y,s);
      if not((a=char(13)) or (a=char(8)) ) then z:=z+a;
      if a=char(13) then done:=true;
      if a=char(8) then
      begin
	 s:=z;
	 z:='';
	 for i:= 1 to length(s)-1 do z :=z + s[i];
      end;
      setcolor(7);
      s:=z+'_';
      outtextxy(x,y,s);
   end;
   ginput:=z;
end;

function pickcolor:byte;
var c:byte;
	d:boolean;
	a:char;
	i:byte;
begin
   for i:= 0 to 255 do
   begin
      setcolor(i);
      line(i,190,i,200);
   end;
   c:=0;
   putpixel(c,189,15);
   d:=false;
   while not(d) do
   begin
      while not(keypressed) do;
      a:=readkey;
      putpixel(c,189,0);
      if a='.' then c:=c+1;
      if a=',' then c:=c-1;
      if a='>' then c:=c+10;
      if a='<' then c:=c-10;
      if c<0 then c:=255;
      if c>255 then c:=0;
      if a=char(13) then d:=true;
      putpixel(c,189,15);
      setfillstyle(solidfill,c);
      bar(260,190,270,200);
   end;
   pickcolor:=c;
end;

procedure specialkey;
var tpc:word;
	a:char;
begin
   putpixel(x,y,lc);
   a:=readkey;
   if a=char(72) then y:=y-1;
   if a=char(80) then y:=y+1;
   if a=char(75) then x:=x-1;
   if a=char(77) then x:=x+1;
   if x<0 then x:=0;
   if x>(sx-1) then x:=sx-1;
   if y<0 then y:=0;
   if y>(sy-1) then y:=sy-1;
   lc:= getpixel(x,y);
   tpc:=lc xor 15;
   if ((tpc=0) or (tpc=255)) then tpc:=15;
   putpixel(x,y,tpc);
end;

procedure pickpoint;
var dn:boolean;
	a:char;
begin
   dn:=false;
   while not(dn) do
   begin
      while not(keypressed) do;
      a:=readkey;
      if a=char(0) then specialkey;
      if a=char(13) then dn:=true;
   end;
end;

procedure rarea;
var cols:array[0..9] of word;
	i,c:integer;
begin
   img.done;
   temp.done;
   putpixel(x,y,lc);
   img.get(0,0,sx-1,sy-1);
   temp.get(0,0,sx-1,sy-1);
   setcolor(7);
   for i:=0 to 9 do
   begin
      cols[i]:=pickcolor;
      setcolor(cols[i]);
      outtextxy(i*8,0,'O');
   end;
   for i:=0 to (sx-1) do
      for c:=0 to (sy-1) do
      begin
	 putpixel(i,c,cols[random(9)]);
      end;
   img.done;
   img.get(0,0,sx-1,sy-1);
   lc:=cols[random(9)];
end;

procedure line;
var x1,x2,y1,y2:integer;
begin
   img.done;
   temp.done;
   putpixel(x,y,lc);
   img.get(0,0,sx-1,sy-1);
   temp.get(0,0,sx-1,sy-1);
   {pickpoint;}
   x1:=x;y1:=y;lc:=cc;
   pickpoint;
   x2:=x;y2:=y;
   setcolor(cc);
   img.put(0,0,0);
   graph.line(x1,y1,x2,y2);
   img.done;
   img.get(0,0,sx-1,sy-1);
end;

procedure circle;
var cx,cy,r:integer;
	a:char;
	d:boolean;
begin
   img.done;
   temp.done;
   putpixel(x,y,lc);
   img.get(0,0,sx-1,sy-1);
   temp.get(0,0,sx-1,sy-1);
   {pickpoint;}
   r:=1;
   d:=false;
   cx:=x;
   cy:=y;
   while not(d) do
   begin
      setcolor(cc);
      graph.circle(cx,cy,r);
      while not(keypressed) do;
      a:=readkey;
      setcolor(0);
      graph.circle(cx,cy,r);
      if a='+' then r:=r+1;
      if a='-' then r:=r-1;
      if a=char(13) then d:=true;
   end;
   temp.put(0,0,0);
   setcolor(cc);
   graph.circle(cx,cy,r);
   img.done;
   img.get(0,0,sx-1,sy-1);
end;

procedure recursiveFill(cx,cy ,depth : integer);
begin
   rf:=true;
   fx:=cx;
   fy:=cy;
   if not(getPixel(cx,cy)=lc) then exit;
   if (cx<0) then exit;
   if (cy<0) then exit;
   if (cx>sx-1) then exit;
   if (cy>sy-1) then exit;
   putpixel(cx,cy,cc);
   rf:=false;
   if depth>4000 then exit;
   rf:=true;
   recursiveFill(cx+1,cy,depth+1);
   recursiveFill(cx,cy+1,depth+1);
   recursiveFill(cx-1,cy,depth+1);
   recursiveFill(cx,cy-1,depth+1);
end;

procedure fill;
var fc,cc:byte;
	i,c:integer;
begin
   img.done;
   temp.done;
   putpixel(x,y,lc);
   temp.get(0,0,sx-1,sy-1);
   fx:=x;
   fy:=y;
   rf:=false;
   while not(rf) do recursiveFill(fx,fy,0);
   lc:=cc;
   putpixel(x,y,lc);
   img.get(0,0,sx-1,sy-1);
end; { fill }

procedure listfiles;
var  DirInfo : SearchRec;
     x,y     : integer;
begin
   x:=0; y:=16;
   FindFirst('*.gfx',0, DirInfo);
   while DosError = 0 do
   begin
      outtextxy(x,y,DirInfo.Name);
      x:=x+(13*8);
      if (x>(320-96)) then
      begin
	 x:=0;
	 y:=y+8;
      end;
      FindNext(DirInfo);
   end;
end; { listfiles }

procedure save;
var s  : string;
   out : text;
   a   : char;
   i,c : integer;
begin
   img.done;
   temp.done;
   putpixel(x,y,lc);
   img.get(0,0,sx-1,sy-1);
   temp.get(0,0,sx-1,sy-1);
   clearviewport;
   setcolor(7);
   listfiles;
   outtextxy(0,0,'Enter the name of the file to save');
   s:=ginput(0,8);
   img.put(0,0,0);
   {save the file}
   s:=s+'.gfx';
   assign(out,s);
   rewrite(out);
   a:=char(sx);
   write(out,a);
   a:=char(sy);
   write(out,a);
   for i:= 0 to sy-1 do
      for c:= 0 to sx-1 do
      begin
	 a:= char( getpixel(c,i) );
	 write(out,a);
      end;
   close(out);   
end; { save }

procedure load;
var s : string;
   i  : image;
begin
   img.done;
   temp.done;
   putpixel(x,y,lc);
   clearviewport;
   setcolor(7);
   listfiles;
   outtextxy(0,0,'Enter the name of the file to load');
   s:=ginput(0,8);
   s:=s+'.gfx';
   i.load('.\',s);
   i.display(0,0,0);
   sx := i.xsize;
   sy := i.ysize;
   lc:=getpixel(x,y);
   img.get(0,0,sx-1,sy-1);
   temp.get(0,0,sx-1,sy-1);
end; { load }

procedure import;
var s  : string;
   inf : text;
   i,c : byte;
   col, code : integer;
begin
   img.done;
   temp.done;
   putpixel(x,y,lc);
   clearviewport;
   setcolor(7);
   listfiles;
   outtextxy(0,0,'Enter file name to import (QBasic format)');
   s:=ginput(0,8);
   assign(inf,s);
   reset(inf);
   for c:= 0 to 9 do
      for i:= 0 to 9 do
	 begin
	    readln(inf,s);
	    val(s,col,code);
	    putpixel(i,c,col);
	 end;   
   close(inf);
   sx:=10;
   sy:=10;
   x:=0; y:=0;
   lc:=getpixel(x,y);
   img.get(0,0,sx-1,sy-1);
   temp.get(0,0,sx-1,sy-1);   
end;

procedure double;
var i,c,z,w,a	: integer;
begin
   if ((sx>100) or (sy>100)) then exit;
   putpixel(x,y,lc);
   for i:= 0 to sx-1 do
      for c:= 0 to sy-1 do
      begin
	 z:=(i*2)+100;
	 w:=(c*2);
	 a:= getpixel(i,c);
	 putpixel(z,w,a);
	 putpixel(z+1,w,a);
	 putpixel(z,w+1,a);
	 putpixel(z+1,w+1,a);
      end;
   sx:=sx*2;
   sy:=sy*2;
   img.done;
   temp.done;
   img.get(100,0,sx+99,sy-1);
   temp.get(100,0,sx+99,sy-1);
   lc:= getpixel(x,y);
   img.put(0,0,0);
end; { double }

procedure mirror;
var i,c,p : byte;
begin
   img.done;
   temp.done;
   putpixel(x,y,lc);
   temp.get(0,0,sx-1,sy-1);
   temp.put(sx+10,0,0);
   for i:= 0 to sx-1 do
      for c:= 0 to sy-1 do
	 begin
	    p := getpixel((2*sx)+9 - i,c);
	    putpixel(i,c,p);
	 end;
   img.get(0,0,sx-1,sy-1);
   lc:= getpixel(x,y);
end;

procedure rotate;
var
   i,c,p : byte;
begin
   img.done;
   temp.done;
   putpixel(x,y,lc);
   temp.get(0,0,sx-1,sy-1);
   temp.put(sx+10,0,0);
   for i:= 0 to sx-1 do
      for c:= 0 to sy-1 do
	 begin
	    p := getpixel((2*sx)+9 - c,i);
	    putpixel(i,c,p);
	 end;
   img.get(0,0,sx-1,sy-1);
   lc:= getpixel(x,y);
end;


procedure keyhandler(a:char);
begin
   if a=char(0) then specialkey;
   if a='I' then import;
   if a='M' then mirror;
   if a='A' then rotate;
   if a='S' then save;
   if a='D' then double;
   if a='O' then load;
   if a='F' then fill;
   if a='R' then rarea;
   if a='L' then line;
   if a='C' then circle;
   if a=' ' then lc:=cc;
   if a='G' then cc:=lc;
   if a='T' then cd:=not(cd);
   if cd then lc:=cc;
   if a='P' then
   begin
      putpixel(x,y,lc);
      img.done;
      img.get(0,0,sx-1,sy-1);
      cc:=pickcolor;
      img.put(0,0,0);
   end;
   if a='U' then
   begin
      img.done;
      temp.put(0,0,0);
      img.get(0,0,sx-1,sy-1);
      lc:=getpixel(x,y);
   end;
end;

procedure run;
var e:boolean;
	a:char;
begin
   e:=false;
   while not(e) do
   begin
      while not(keypressed) do;
      a:=readkey;
      a:=upcase(a);
      if a='Q' then e:=true;
      keyhandler(a);
   end;
end;

begin
   init;
   img.get(0,0,sx-1,sy-1);
   temp.get(0,0,sx-1,sy-1);
   run;
   img.done;
   temp.done;
   done;
end.
