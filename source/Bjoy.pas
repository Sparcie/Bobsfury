{ Bob joystick Unit 2005 A Danson}
{ updated end of 2014 to make for a better and more usable interface
  also added functionality for customising the controls.}

unit bjoy;

interface

type
   joystick = record
		 xaxis,yaxis	 : word;
		 xcentre,ycentre : word;
		 buttons         : byte;
	      end;		 

var
   joy       : joystick;
   joyavail  : boolean;
   usejoy    : boolean;
   jcbuttons : array[1..4] of byte; {1 fire 2 jump 3 change weapon 4 health b}

const
	BUTTON_A = $10;
        BUTTON_B = $20;
        BUTTON_C = $40;
        BUTTON_D = $80;

procedure update;
procedure calibrate;
function xcentred:boolean;
function ycentred:boolean;
function joypressed( b : byte ):boolean;


implementation

const
   joyport =  $201;

   function count(bit : byte):word;
   var
      c	: word;
   begin
      asm
          cli
          mov ah,bit
          mov al,$FF
          mov cx,$FFFF
          mov dx,joyport
          out dx, al
      @read:
	  in al,dx
	  test al,ah
	  loopnz @read
	  mov c,cx
          sti
      end;
      count:=c;
   end;


   function joypressed( b : byte ):boolean;
   begin
      joypressed := (joy.buttons and jcbuttons[b]) = 0;
   end;

   procedure calibrate;
   begin
      joy.xcentre := joy.xaxis;
      joy.ycentre := joy.yaxis;
   end; { calibrate }

   function xcentred:boolean;
   var z : integer;
   begin
      z:= joy.xcentre div 5;
      xcentred := false;
      if abs(joy.xaxis-joy.xcentre)<z+1 then xcentred:=true;
   end; { xcentred }

   function ycentred:boolean;
   var z : integer;
   begin
      z:= joy.ycentre div 5;
      ycentred := false;
      if abs(joy.yaxis-joy.ycentre)<z+1 then ycentred:=true;
   end; { ycentred }

   procedure update;
   var
      c	: word;
   begin
      c := count($01);
      joy.xaxis := $FFFF-c;
      c := count($02);
      joy.yaxis := $FFFF-c;
      joy.buttons:=port[joyport];
      if not((joy.xaxis=$FFFF) or (joy.yaxis=$FFFF)) then
	    joyavail := true
	 else
	    joyavail:=false;
   end; { update }


begin
   joyavail:=false;
   update;
   usejoy:=false;
end.
