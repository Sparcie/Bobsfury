{makes a blank bobs fury map. (required for bfleu)}
program makeblank;

uses map;

var
  i,c,l:integer;

begin
      i:=0;
      c:=0;
      while c < 17 do
      begin
	 while i< 31 do
	 begin
	    changescreen(1);
	    setobjectat(i,c,0);
	    changescreen(2);
	    setobjectat(i,c,0);
	    changescreen(3);
	    setobjectat(i,c,0);
	    changescreen(4);
	    setobjectat(i,c,0);
	    i:=i+1;
	 end;
	 i:=0;
	 c:=c+1;
      end;
  save('blank.map');
end.