{ Common code for various graphics units such as VGA and CGA

  A Danson 2022 }

unit gcommon;

interface

{swaps the a and b parameters}
procedure swapW(var a,b:word);
{swaps the a and b parameters}
procedure swapI(var a,b:integer);
{returns 1 or -1 depending on the sign of i}
function sign(i : integer): integer;
{check if co-ordinates are on screen}
function checkBounds(x,y:integer):boolean; {returns true on failure!}
{copy memory routine}
procedure copymem(srcseg,srcofs,destseg,destofs,count:word);
{fill memory routine}
procedure fillmem(sgm, ofs:word; d: byte; count:word);

implementation

{fill memory routine}
procedure fillmem(sgm, ofs:word; d: byte; count:word); assembler;
asm
   {set up the counter}
   mov cx, count
   shr cx, 1
   {set the direction}
   cld
   {load data in the AX register}
   mov al, d
   mov ah, al
   {load the destination pointer}
   mov bx, sgm
   mov es, bx
   mov bx, ofs
   mov di, bx
   {use rep stosw to store the data}
   rep stosw
   {check if there is one last byte to copy (an odd numbered count)}
   {luckily the carry bit isn't touched from the shr earlier}
   jnc @done
   stosb
@done:
end;

{copy memory routine}
procedure copymem(srcseg,srcofs,destseg,destofs,count:word); assembler;
asm
    push ds
    {load the count and divide by 2}
    mov cx, count
    shr cx, 1
    {set direction}
    cld
    {load the source pointer}
    mov bx, srcseg
    mov ds, bx
    mov bx, srcofs
    mov si, bx
    {load the destination pointer}
    mov bx, destseg
    mov es, bx
    mov bx, destofs
    mov di, bx
    {use movsw to copy the data}
    rep movsw
    {copy the last byte if needed (an odd count)}
    {luckily the carry flag is unchanhed from the shr}
    jnc @done
    movsb
@done:
    pop ds
end;


{swaps the a and b parameters}
procedure swapW(var a,b:word);
var
   x:word;
begin
     x:= a;
     a:= b;
     b:= x;
end;

{swaps the a and b parameters}
procedure swapI(var a,b:integer);
var
   x:integer;
begin
     x:= a;
     a:= b;
     b:= x;
end;


{returns 1 or -1 depending on the sign of i}
function sign(i : integer): integer;
begin
    sign :=0;
    if i>0 then sign:=1;
    if i<0 then sign:=-1;
end;

{check if co-ordinates are on screen}
function checkBounds(x,y:integer):boolean; {returns true on failure!}
begin
    checkBounds := false;
    if ((x<0) or (x>319)) then checkBounds := true;
    if ((y<0) or (y>199)) then checkBounds := true;
end;



end.
