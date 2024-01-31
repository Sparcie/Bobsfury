
# Bob's Fury

Bob's fury is a game project I started back when I was a teenager. This is the pascal port I've been
working on since around 1999.

It's a work in progress and includes levels from the much older QBasic version of the game.

If you have any feedback please send me a message on twitter @Sparcie2
or communicate here through Github.

It's a work in progress (ie. it's not complete) and includes two sets of levels from the much older
Qbasic version of the game I wrote as a teenager.

### Requirements

The game requires about 256-300K of memory and a graphics card (CGA, EGA, VGA or VESA/SVGA).
It will run on 8088/8086 machines with best results being on an 8Mhz 8086 or faster. Slower machines
will work but with inconsistent performance at normal speed. Setting the game speed to slow will
improve this. Any 286 and faster should work fine.

There is now a XT specific build of the game available, it is limited to CGA and PC speaker sound but
significantly reduces the memory and processor requirments. You can squeeze this version into 200k of
available memory.

If you are experiencing slow down, there are a couple of options.
Some graphics modes are slower than others. The speed of the modes from slowest to fastest is: VESA/SVGA, EGA, VGA, CGA.
Lesser graphics modes also use less memory which is useful on machines with less RAM.

The game supports Adlib, PC speaker and the OPLxLPT devices which you can select with command line options.  
The default behaviour is to use Adlib if detected and fall back to PC speaker if it isn't. Disabling Ad-Lib
sound will save you some memory and performance as well if you need it.

Music support has been made, but I haven't made any serious effort to compose any suitable music yet
(the available music is for testing only), this option is best left turned off.

The game remembers the hardware configuration between sessions, command line switches are only required to change
what is currently used.

### Trouble shooting Tips

I have done some testing on real hardware, but since what I have is extremely limited I can't guarantee
it will work perfectly on your system. Dosbox works quite well with pretty much the default settings. If you
have a problem please report a bug by posting a comment on my blog, twitter or and issue on github.

If you have a speed issue with VESA graphics it seems some VESA extensions can cause the issue. As a work
around you can disable doulbling the pit speed.

If you see run time error 203, that basically means you're running out of memory.

### Future

I'm obviously still working on this so changes will be made over time, hopefully adding more levels, but
perhaps also other features as I need them. I'm doing this in my spare time, of which I have very little,
so progress is slow. There will be updates, but there may be some significant time between them.

Some things I don't plan on changing.
 - I'm not going to add smooth scrolling. It would be too big a change to the code base and wouldn't be
      faithful to the QBasic original. 
 - I'm not going to add digitised Sound blaster sound. I am considering adding CMS support but it's not planned
      at this stage.

### Command Line

   bob /? -e -cga -h -l -n -a -s -c <file.map>
   
   /? = shows a list of command line options
   
   -e   = EGA graphics mode (640x200x16)
   -cga = CGA graphics mode (320x200x4)
   -l   = VGA graphics mode (320x200x256) (default)
   -h   = VESA/SVGA graphics mode (640x400x256)
   
   -n   = Force sound to be turned off.
   -a   = Auto detect Adlib or PC Speaker
   -s   = Force using the PC Speaker
   LPT1 = use the OPL2LPT on LPT1
   LPT2 = use the OPL2LPT on LPT2
   
   -np  = disable doubling the PIT speed
   
   -c <File.map> = used for loading a level directly.

### License

Bob's Fury is Freeware. This means you get to play with it for free, but I still own it.
