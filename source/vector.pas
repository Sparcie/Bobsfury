{Vector 2d unit A Danson 1998}
unit vector;

interface
	function calcbearing(x1,y1,x2,y2:real):real;
	procedure calcvector(var brg,sp,rx,ry:real);
        function distance(x,y,x2,y2:real):real;
implementation

function calcbearing(x1,y1,x2,y2:real):real;
var a,b,c:real;
begin
	if (y1<y2) and (x1>x2) then
		begin
		a:=y1-y2;
		b:=sqrt(sqr(x1-x2)+sqr(y1-y2));
		c:=abs(a/b);
		a:=arctan(c/sqrt((c*-1)*c+1)) +(pi/2);
		a:=a*(360/(2*pi));
		calcbearing:=360-a;
		end;
	if (y1<y2) and (x1<x2) then
		begin
		a:=y1-y2;
		b:=sqrt(sqr(x1-x2)+sqr(y1-y2));
		c:=abs(a/b);
		a:=arctan(c/sqrt((c*-1)*c+1)) +(pi/2);
		a:=a*(360/(2*pi));
		calcbearing:=a;
		end;
	if (y1>y2) and (x1<x2) then
		begin
		a:=y2-y1;
		b:=sqrt(sqr(x1-x2)+sqr(y1-y2));
		c:=abs(a/b);
		a:=arctan(c/sqrt((c*-1)*c+1)) +(pi/2);
		a:=a*(360/(2*pi));
		calcbearing:=180-a;
		end;
	if (y1>y2) and (x1>x2) then
		begin
		a:=y2-y1;
		b:=sqrt(sqr(x1-x2)+sqr(y1-y2));
		c:=abs(a/b);
		a:=arctan(c/sqrt((c*-1)*c+1)) +(pi/2);
		a:=a*(360/(2*pi));
		calcbearing:=180+a;
		end;
	if (x1=x2) and (y1>y2) then calcbearing:=0;
	if (x1=x2) and (y1<y2) then calcbearing:=180;
	if (y1=y2) and (x1<x2) then calcbearing:=90;
	if (y1=y2) and (x1>x2) then calcbearing:=270;
end;

procedure calcvector(var brg,sp,rx,ry:real);
var e:real;
begin
        rx:=0;
        ry:=0;
	e:=brg;
	if e=0 then
		begin
		rx:=0;
		ry:=-1*sp;
		end;
	if e=90 then
		begin
		rx:=sp;
		ry:=0;
		end;
	if e=180 then
		begin
		rx:=0;
		ry:=sp;
		end;
	if e=270 then
		begin
		rx:=-1*sp;
		ry:=0;
		end;
	if (e>0) and (e<90) then
		begin
		rx:=(sp*sin(e*(pi/180)));
		ry:=-1*(sp*cos(e*(pi/180)));
		end;
	if (e>90) and (e<180) then
		begin
		e:=e-90;
		ry:=(sp*sin(e*(pi/180)));
		rx:=(sp*cos(e*(pi/180)));
		end;
	if (e>180) and (e<270) then
		begin
		e:=e-180;
		rx:=-1*(sp*sin(e*(pi/180)));
		ry:=(sp*cos(e*(pi/180)));
		end;
	if (e>270) and (e<360) then
		begin
		e:=e-270;
		ry:=-1*(sp*sin(e*(pi/180)));
		rx:=-1*(sp*cos(e*(pi/180)));
		end;
end;

function distance(x,y,x2,y2:real):real;
begin
 distance := sqrt(sqr(x-x2)+sqr(y-y2));
end;

end.



		
