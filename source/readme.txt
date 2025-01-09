
This is the collection of source code for Bob's Fury
If you're reading this I hope you're prepared! Much of this code
has been written at various stages of learning Pascal so the design
and layout may not be optimal.

I'm using Turbo Pascal 6 to compile this, however it should also
compile with 7 as well.

I use emacs to edit these files, you may wish to use dos2unix or unix2dos 
to convert them to read in your favourite editor.

File List
---------

Here's a list of the pascal source files and a brief description

defines.pas  - sets up conditional defines for each build type - primarily for hardware support selection (this file is included rather than used)
Bjoy.pas     - Joystick hardware interface
Bsystem.pas  - contained utility functions that have gradually been superseeded over time. Checkfile (for checking a file exists) is all that remains
RLE.pas      - Run length encoder object - not actually used, but formed the basis of adding RLE compression to graphics and maps
bconfig.pas  - Loads/saves the configuration file - some very old code!
bfleu.pas    - level editor
blankmap.pas - creates the blank.map that was needed in some cases.
bmenu.pas    - The menu interface for the game (includes high scores, save/load, settings and introduction screens)
bmusic.pas   - unit that stores and manages a peice of music (includes some editing function not used in the game)
bobgraph.pas - intermediate graphics interface to make sure different resolutions work, also provides the basic animations.
bfont.pas    - Replacement for BGI stroked font drawing. loads a font and allows writing text to screen.
gcommon.pas  - common functions for device dependant graphics code.
CGA.pas      - CGA device dependant code for graphics library.
VGA.pas      - VGA device dependant code for graphics library.
EGA.pas      - EGA device dependant code for graphics library.
VESA.pas     - VESA device dependant code for graphics library.
bobtest.pas  - Main program for the game - interprets parameters and has main loop.
bsound.pas   - base sound interface for sound effects and music
buffer.pas   - a simple buffered file reader/writer for text type files
compress.pas - compression program using huffman coding (see huffdec and huffenc)
convert.pas  - converts Qbasic levels to the Pascal level format
engine.pas   - main game engine - probably the ugliest and oldest code. Been refactored a little.
fixed.pas    - library for fixed math - used mainly for the integer Square root and distance calculations
fmmusic.pas  - turns Q/GWBasic style play strings into note data for other sound libraries (not used in the game, but rather to generate the data beforehand)
fmplayer.pas - Code for handling the playback of audio on the adlib, mostly has buffers and the int 1C interrupt
fmsynth.pas  - Lowest level interface for talking to adlib/OLP2LPT devices (code for sending data to the devices)
huffdec.pas  - Huffman code decoder unit.
huffenc.pas  - Huffman code encoder unit.
joytest.pas  - test program for joystick unit.
keybrd.pas   - keyboard hardware interface 
keytest.pas  - Keyboard test program
llist.pas    - level list - maintains list of levels in an episode, also text blocks associated with them.
map.pas      - level data unit - some heavily modified older code.
mapcomp.pas  - map compression program - compresses previously uncompressed maps
mconvert.pas - Music converter - converts music text files (with BASIC play syntax) to the music format - not the best way to make music.
medit.pas    - Music editor - still a work in progress 
music.pas    - PC speaker sound unit by J C Kessels - plays sound using the BASIC play syntax, modified to cope with increased timer rate
palgen.pas   - generates VGAPAL.pas (stores VGA palette)
pgs.pas      - packed graphics system, loads graphics packs (decodes RLE format), initialises video, some basic collision (box) detection between sprites, and drawing sprites.
pitdbl.pas   - PIT doubler - doubles the PIT speed (optionally), could go to a higher rate if modified.
sbiibk.pas   - unit for loading data from SBTimbre (instrument information for adlib device from external program)
synthint.pas - intermediate interface to adlib device - play notes and does basic rythm section stuff.
testfm.pas   - test program for fmplayer, sythint and fmsynth
testm.pas    - test program for bmusic, fmmusic
vector.pas   - Old unit for calulating distance - not used anymore.
PALETTE.PAS  - VGA palette interface (changes colours)
SNDGEN.PAS   - creates the sound cache file for sound effect playback.
VGAPAL.PAS   - generated from palgen.pas. const VGA palette.
scache.PAS   - Sound cache - stores sound effects in a ready to use form (notes ready for fmplayer)

License
-------
I can't imagine why you'd want to use my code, but feel free to as long as it's non-comercial.
The PC speaker Music unit (music.pas) belongs to J. C. Kessels and was a free to use download - I'd suggest crediting him if you use this. The site I got it from is long gone!


The game itself is freeware. That means I own it but you can play it for free.
