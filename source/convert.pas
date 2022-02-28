{converts qbasic bobsfury levels to the current pascal ones}
program converter;

uses map,dos;

var fname:array[0..100] of string;
    num,up:integer;

procedure det;
var name:string;
   DirInfo: SearchRec;
begin
   FindFirst('*.dat',0, DirInfo);
   while DosError = 0 do
   begin
      fname[num]:=Dirinfo.Name;
      Write(fname[num]+' ');
      num:=num+1;
      FindNext(DirInfo);
   end;
end;

function rd(var f:text):byte;
var res,zz,d:byte;
    st:string[4];
    ic,cc:integer;
    az:char;
begin
   res:=0;
   readln(f,st);
   for ic := 0 to 3 do
   begin
      az:=st[ic];
      zz:=ord(az);
      if ((zz>47) and (zz<58)) then cc:=ic;
   end;
   for ic:=0 to cc do
   begin
      az:=st[ic];
      zz:=ord(az);
      zz:=zz-48;
      if ((zz<10)) then
	 res:= res+(zz);
      if (cc-ic>0) then res:=res * 10;
   end;
   writeln(res,' ',cc);
   rd:=res;
end;

procedure convert(fle:string);
var inf:text;
    i,c,zc:integer;
    b,a:byte;
    r:boolean;
    tm:string;
begin
   i:=0;
   c:=0;
   assign(inf,fle);
   reset(inf);
   while (c<61) do
   begin
      i:=0;
      while (i<16) do
      begin
	 b:=rd(inf);
	 a:=b;
	 if b=14 then a:=15;
	 if b=13 then a:=0;
	 if b=12 then a:=14;
	 if b=11 then a:=10;
	 if b=10 then a:=11;
	 if b=9 then a:=28;
	 if b=8 then a:=9;
	 if b=7 then a:=22;
	 if b=6 then a:=23;
	 if b=5 then a:=21;
	 if b=4 then a:=30;
	 if b=3 then a:=38;
	 if b=2 then a:=18;
	 if b=1 then a:=6;
	 if c>30 then zc:=c-30 else zc:=c;
	 if c<31 then changescreen(1) else changescreen(2);
	 setobjectat(zc,i,a);
	 i:=i+1;
      end;
      c:=c+1;
   end;
   close(inf);
   changescreen(3);
   for i := 1 to 30 do
      for c:= 0 to 15 do
	 setobjectat(i,c,6);
   r:=false;
   tm:='';
   for i:=1 to 12 do
   begin
      if fle[i]='.' then r:=true;
      if not(r) then tm:=tm+fle[i];
   end;
   fle:=tm+'.map';
   save(fle);
end;

begin
   num:=0;
   det;
   up:=0;
   for up:=0 to (num-1) do
   begin
      writeln('converting '+fname[up]+'....');
      convert(fname[up]);
   end;
end.
