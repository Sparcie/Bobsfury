{ sbiibk : A J Danson 2012
  This unit is for reading the SBI and IBK files that are with/from
  sbtimbre the adlib instrument making program.
}

unit sbiibk;

interface

uses synthint;

type
   timbre  = record
		modchar	  : byte; { AM, VIB, SUS, KSR, MUL}
		carchar	  : byte;
		modscal	  : byte; {KSL, TL}
		carscal	  : byte;
		modad	  : byte; {attack/decay}
		carad	  : byte;
		modsr	  : byte; {sustain/release}
		carsr	  : byte;
		modwave	  : byte; {wave select}
		carwave	  : byte;
		feedback  : byte; {feedback?}
		percvoc	  : byte; {percussion voice?}
		transp	  : shortint; {transpose amount?}
		percpitch : byte; {percusion pitch}
		unused	  : word; {unused!}
	     end;	  
   sbiFile = record
		sig   : array[0..3] of char;
		name  : array[0..31] of char;
		instr : timbre;
	     end;     
   ibkFile = record
		sig   : array[0..3] of char;
		insts : array[0..127] of timbre;
		names : array[0..127] of string[9];
	     end;     
   sbiptr  = ^sbiFile;

var
   ibk	     : ibkFile;

function loadSBI(fname : string):sbiptr ;
procedure loadIBK(fname : string);
procedure convertTimbre(t : timbre;var result :instrument);
			    
implementation

function loadSBI(fname : string):sbiptr;
var
   sbfile : sbiptr;
   rf	  : file;
   br	  : word;
begin
   new(sbfile);
   assign(rf,fname);
   reset(rf,1);
   blockread(rf,sbfile^,sizeof(sbiFile),br);
   if (br<>sizeof(sbiFile)) then
   begin
      writeln('Error reading SBI File: ' + fname);
      halt(0);
   end;
   close(rf);
end; { loadSBI }

procedure loadIBK(fname : string);
var
   rf : file;
   br : word;
begin
   assign(rf,fname);
   reset(rf,1);
   blockread(rf,ibk,sizeof(ibkFile),br);
   if (br<>sizeof(ibkFile)) then
   begin
      writeln('Error reading IBK File: '+fname);
      halt(0);
   end;
   close(rf);
end; { loadIBK }

procedure convertTimbre(t : timbre; var result :instrument);
begin
   result.mult1 := t.modchar;
   result.mult2 := t.carchar;
   result.keys1 := t.modscal;
   result.keys2 := t.carscal;
   result.att1 := t.modad;
   result.att2 := t.carad;
   result.sust1 := t.modsr;
   result.sust2 := t.carsr;
   result.feed := t.feedback;
   result.wave1 := t.modwave;
   result.wave2 := t.carwave;
end;

end.