unit palette;

interface

type
  paltype = array [0..255,0..2] of byte;

procedure SetColor(number, r,g,b: byte);
procedure GetColor(number: byte; var r,g,b: byte);
procedure SetPalette(pal: paltype);
procedure GetPalette(var pal: paltype);
function  StepPalette(var p: paltype; pal: paltype): boolean;

implementation

procedure SetColor;
begin
   port[$3c8]:=number;
   port[$3c9]:=r;
   port[$3c9]:=g;
   port[$3c9]:=b;
end;

procedure GetColor;
begin
   port[$3c7]:=number;
   r:=port[$3c9];
   g:=port[$3c9];
   b:=port[$3c9];
end;

procedure SetPalette;
var i: integer;
begin
   for i:=0 to 255 do SetColor(i,pal[i,0],pal[i,1],pal[i,2]);
end;

procedure GetPalette;
var i: integer;
begin
   for i:=0 to 255 do GetColor(i,pal[i,0],pal[i,1],pal[i,2]);
end;

function StepPalette(var p: paltype; pal: paltype): boolean;
var i: integer; b: boolean;
begin
   b:=false;
   for i:=0 to 255 do
   begin
      if p[i,0]<pal[i,0] then begin inc(p[i,0]); b:=true; end;
      if p[i,0]>pal[i,0] then begin dec(p[i,0]); b:=true; end;
      if p[i,1]<pal[i,1] then begin inc(p[i,1]); b:=true; end;
      if p[i,1]>pal[i,1] then begin dec(p[i,1]); b:=true; end;
      if p[i,2]<pal[i,2] then begin inc(p[i,2]); b:=true; end;
      if p[i,2]>pal[i,2] then begin dec(p[i,2]); b:=true; end;
   end;
   StepPalette:=b;
end;

end.
