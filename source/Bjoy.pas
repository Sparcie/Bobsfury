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

   procedure count(var x,y :word ); assembler;
   asm
          cli {disable interrupts - to minimise noise }
          mov al,$FF
          mov cx,$FFFF
          mov bx,$FFFF
          mov dx,joyport
          xor ah,ah
      {read both axis }
          out dx, al
      @read:
	  in al,dx
          {dec x counter if needed with constant number of cycles}
          mov di, ax
          and di, $01
          sub cx, di
          jz @break {check for timeout and break if needed}
          {dec y counter if needed with constant number of cycles}
          mov di, ax
          and di, $02
          shr di, 1
          sub bx, di
          jz @break {check for timeout on y axis}
   
          test al,$03 {test and loop if either axis is still active}
          jnz @read
      @break:
          sti {loop done enable interrutps}

          {push the counters to the vars}
          les di, x
          mov es:[di], cx
          les di, y
          mov es:[di], bx
          {done!}
   end;


   function joypressed( b : byte ):boolean;
   begin
      joypressed := false;
      if not(joyavail) then exit;
      if b > 0 then
	 joypressed := (joy.buttons and jcbuttons[b]) = 0
      else
	 joypressed := (joy.buttons and $F0) < $F0;
   end;

   {during calibration you need the stick to be in the centre}
   procedure calibrate;
   var i	: word;
      xData	: array[0..255] of word;
      yData	: array[0..255] of word;
      xsum,ysum	: longint;
      delta	: word;
   begin
      {calibrate the input - do loads of samples and calculate average and estimated deadzone}
      xsum := 0;
      ysum := 0;
      for i:= 0 to 255 do
      begin
	 count(xdata[i], ydata[i]);
	 xdata[i] := $FFFF - xdata[i];
	 ydata[i] := $FFFF - ydata[i];
	 xsum := xsum + xData[i];
	 ysum := ysum + yData[i];
      end;
      {calculate the average as the centre}
      joy.xcentre := xsum div 256;
      joy.ycentre := ysum div 256;
      
      { determine the max delta from the centre - determine how noisy the stick is }
      joy.xdeadzone := 5;
      joy.ydeadzone := 5;
      for i:=0 to 255 do
      begin
	 delta := abs(integer(joy.xcentre) - integer(xData[i]));
	 if (delta > joy.xdeadzone) then joy.xdeadzone := delta + 5;
	 delta := abs(integer(joy.ycentre) - integer(yData[i]));
	 if (delta > joy.ydeadzone) then joy.ydeadzone := delta + 5;
      end;
   end; { calibrate }

   function xcentred:boolean;
   begin
      if not(joyavail) then
      begin
	 xcentred := true;
	 exit;
      end;
      xcentred := false;
      if abs(Integer(joy.xaxis)-Integer(joy.xcentre))< joy.xdeadzone then xcentred:=true;
   end; { xcentred }

   function ycentred:boolean;
   var z : integer;
   begin
      if not(joyavail) then
      begin
	 ycentred := true;
	 exit;
      end;
      ycentred := false;      
      if abs(Integer(joy.yaxis)-Integer(joy.ycentre))< joy.ydeadzone then ycentred:=true;
   end; { ycentred }

   procedure update;
   begin
      count(joy.xaxis, joy.yaxis);
      joy.xaxis := $FFFF-joy.xaxis;
      joy.yaxis := $FFFF-joy.yaxis;
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
