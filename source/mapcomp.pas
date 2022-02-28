{compresses all the levels in the current directory by loading
 and saving them using the new features of the map unit.}

{can be converted to de-compress by included this compile time define}
{define no_RLE}

program mapcomp;

uses map,dos;

var fname:array[0..100] of string;
    num,i:integer;

procedure det;
var name:string;
   DirInfo: SearchRec;
begin
   FindFirst('*.map',0, DirInfo);
   while DosError = 0 do
   begin
      fname[num]:=Dirinfo.Name;
      {Write(fname[num]+' ');}
      num:=num+1;
      FindNext(DirInfo);
   end;
end;

begin
   num := 0;
   det;
   for i:= 0 to (num-1) do
      begin
	 writeln('Compressing '+fname[i]+'...');
	 load(fname[i]);
	 save(fname[i]);
      end;
end.
