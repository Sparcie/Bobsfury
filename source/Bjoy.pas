{ Bob joystick Unit 2005 A Danson}
{ updated end of 2014 to make for a better and more usable interface
  also added functionality for customising the controls.}

unit bjoy;

interface

type
   joystick = record
		 xaxis,yaxis	      : word;
		 xcentre,ycentre      : word;
		 xdeadzone, ydeadzone : word;
		 xmin, ymin	      : word;
		 xmax, ymax	      : word;
		 buttons	      : byte;
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

   {during calibration you need the stick to be in the centre}
   procedure calibrate;
   var i       : word;
      axisData : array[0..255] of integer;
      sum      : longint;
      delta    : word;
   begin
      {calibrate the X axis - do loads of samples and calculate average and estimated deadzone}
      sum := 0;
      for i:= 0 to 255 do
      begin
	 axisData[i] := $FFFF - count($01);
	 sum := sum + axisData[i];
      end;
      {calculate the average as the centre}
      joy.xcentre := sum div 256;
      { determine the max delta from the centre - determine how noisy the stick is }
      joy.xdeadzone := 5;
      for i:=0 to 255 do
      begin
	 delta := abs(joy.xcentre - axisData[i]);
	 if (delta > joy.xdeadzone) then joy.xdeadzone := delta + 5;
      end;
      {calibrate the Y axis - do loads of samples and calculate average and estimated deadzone}
      sum := 0;
      for i:= 0 to 255 do
      begin
	 axisData[i] := $FFFF - count($02);
	 sum := sum + axisData[i];
      end;
      {calculate the average as the centre}
      joy.ycentre := sum div 256;
      { determine the max delta from the centre - determine how noisy the stick is }
      joy.ydeadzone := 5;
      for i:=0 to 255 do
      begin
	 delta := abs(joy.ycentre - axisData[i]);
	 if (delta > joy.ydeadzone) then joy.ydeadzone := delta + 5;
      end;
   end; { calibrate }

   function xcentred:boolean;
   begin
      xcentred := false;
      if abs(Integer(joy.xaxis)-Integer(joy.xcentre))< joy.xdeadzone then xcentred:=true;
   end; { xcentred }

   function ycentred:boolean;
   var z : integer;
   begin
      ycentred := false;
      if abs(Integer(joy.yaxis)-Integer(joy.ycentre))< joy.ydeadzone then ycentred:=true;
   end; { ycentred }

   procedure update;
   var
      c	: word;
   begin
      c := count($01);
      joy.xaxis := $FFFF-c;
      c := count($02);
      joy.yaxis := $FFFF-c;
      {update min/max}
      if joy.xmin > joy.xaxis then joy.xmin := joy.xaxis;
      if joy.xmax < joy.xaxis then joy.xmax := joy.xaxis;
      if joy.ymin > joy.yaxis then joy.ymin := joy.yaxis;
      if joy.ymax < joy.yaxis then joy.ymax := joy.yaxis;      
      
      joy.buttons:=port[joyport];
      if not((joy.xaxis=$FFFF) or (joy.yaxis=$FFFF)) then
	    joyavail := true
	 else
	    joyavail:=false;
   end; { update }


begin
   joy.xmin := $FFFF;
   joy.xmax := 0;
   joy.ymin := $FFFF;
   joy.ymax := 0;
   joyavail:=false;
   update;
   if joyavail then
      calibrate;
   usejoy:=false;
end.
