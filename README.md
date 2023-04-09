NesToy is a NES ROM management utility for your .NES Nintendo/Famicom
ROMs.  This program started out as a header information utility, but now,
using a database, can identify your NES ROMs and optionally repair any bad
headers it finds and rename the ROMs to full descriptive long file names.

NesToy will work under Windows 2000, but has not been fully tested with
this operating system.  If you have any problems or notice any bugs with
Windows 2000 that didn't exist under Windows 95/98, please let me know.

** To enable Windows 2000 support, set WIN2000 to TRUE in NESTOY.CFG.


usage: NesToy.exe [parameters] pathname1 [pathname2] [pathname3] ...

Filenames can include wildcards (*,?) anywhere inside the filename.  Long
file names are allowed and if no filename is specified, (*.nes) is assumed.


Parameters
----------
  -b             Displays PRG and CHR information by # of blocks instead
                 of kB. (Example: Instead of 128kB, you would see 8x16kB)

  -c             Calculate Checksums (CRC-32).  All database operations
                 require this option and currently turn it on when used.
                 Additionally, one of the following will appear next to
                 the filename when -c is used.
                   * - ROM is identified and good.
                   ? - Unknown ROM
                   x - ROM is identified, but something is wrong with it.
                       Use -i for more information.
                   d - ROM is a duplicate
                   n - Name does not match ROM name in database
                   b - ROM is a bad dump

  -hc            Calculate Checksums with header.  This option is here
                 by request.  Cannot be used with any database operations.
                   
  -i             Outputs extended info if header or name are not correct.
                 If the information in a ROM's header does not match that
                 in the database, a second line of data will be displayed
                 illustrating the differences.  You will also see one of
                 the following.  
                   Bad [] - There is something wrong with the ROM.  Refer
                            to the codes inside the brackets for details.
                   Rep [] - The ROM has been repaired.
                   Ren [] - The ROM has been renamed.

                 Inside the brackets will contain one or more of the
                 following codes.
                   N - Name does not match that in database.
                   H - Header contains incorrect mapper info.
                   G - Header contains garbage.
                   T - There is trailing garbage at the end of the ROM.

                 If you see Can't Rename or Can't Repair, it means for
                 some reason, NesToy was unable to rename or repair the
                 ROM.

  -o[file]       Sends output to file. (DOS 8.3 filenames for now) If no
                 filename is specified, it defaults to OUTPUT.TXT.  If file
                 exists, NesToy will append data to the end of the file.
 
  -ren[uscltp]   Renames ROMs to names stored in database (enables -c)
                   u- Replace spaces with underscores
                   s- Remove spaces completely from filename
                   c- Attach country codes to end of filenames
                   l- Convert ROMs to all lowercase names
                   t- Places the word "The" at the beginning of ROM names
                      instead of at the end.
                   p- Use periods in appropriate ROM names (Warning: Nesticle
                      will not load ROMs with extra periods in them.
                      Example: Dr Mario.nes would be named as Dr. Mario.nes

  -rep,-repair   Repairs ROM headers with those found in database (enables -c)
                 File is backed up before repair is made.

  -res,-resize   Automatically resizes ROMs if they contain duplicate or
                 unused banks of data. (enables -c).

  -m#            Filter listing by mapper #.  Example: if -m1 is used, only
                 ROMs with a mapper of 1 will be displayed.

  -f[hvbt4]      Filter listing by mapper data
                    h- Horizontal Mirroring     t- Trainer Present
                    v- Vertical Mirroring       4- 4 Screen Buffer
                    b- Contains SRAM (Battery backup)

  -u             Only display unknown ROMs (enables -c)
                 Only ROMs that are not found in the database will be
                 displayed.  If you have a ROM that you know is good, but
                 it is not in my database, please let me know so I can add
                 it to the database.

  -sub           Process all subdirectories under directories specified on
                 the path.  This only works one level deep.  So if in your
                 ROMS\ directory, you have USA\, JAPAN\, and EUROPE\, using
                 NesToy -sub ROMS\ will process any roms in ROMS\, ROMS\USA\,
                 ROMS\JAPAN\, and ROMS\EUROPE\.

                 NesToy will alway skip over the duplicates directory in a
                 scan unless you directly specify it on the command line.

  -nobackup      Don't make backups before repairing or resizing ROMs.

  -log           Log to NESTOY.LOG any problems NesToy encounters while
                 sorting, renaming, or repairing ROMs.

  -missing[cbn]  Create a listing of missing ROMs.  If listing exists, it
                 will be updated.  Filename is defined in NESTOY.CFG.
                    c- Sort missing list by country
                    b- Bare listing (Name, country codes, and checksum only)
                    n- Force NesToy to create a new missing list, even if
                       one already exists (It will be overwritten.)

                 If a missing list already exists, NesToy will update the
                 list by removing any ROMs from the list that now exist.
                 NesToy will never add ROMs to the missing file, so when a
                 new release comes out with a database update, it is probably
                 a good idea to delete the missing file and have NesToy
                 create a new one to reflect the changes in the database.

                 You can adjust whether or not pirates, hacks, translations,
                 or bad dumps are included in the output in the NESTOY.CFG
                 file. 

  -sort[m]       Sorts ROMs into directories by country or type.
                    m- Sorts ROMs by mapper # as well.

                    PC10- Playchoice 10\     C  - China\
                    VS  - VS Unisystem\      F  - Canada\
                    U   - USA\               S  - Sweden\
                    J   - Japan\             Unl- Unlicensed\
                    E   - Europe\            TR - Translated\
                    ??? - Unknown\
                 Country codes are in order of priority.  In other words,
                 If a ROM is both U and J, it will go into USA\.

                 Bad dumps will go into Bad\, Hacked ROMs will go into
                 Hacked\, Game Hacks\, or Mapper Hacks\ depending on the
                 type of hack.  Pirates will go into Pirate\.  You can also
                 have these go into their corresponding country directory
                 instead.  Just change the MOVE_BAD, MOVE_PIRATE, or
                 MOVE_HACKED in the NESTOY.CFG from TRUE to FALSE.

                 These are the default directories.  These can be changed
                 in the NESTOY.CFG (created the first time you run
                 NesToy.)

  -q[o]          Suppresses output to the screen (for those of you who
                 would prefer not to see what NesToy is up to.)
                    o- Suppresses output to the output file as well.

  -doall         Enables -c,-i,-ren,-repair,-resize,-sort, and -missing.

  -h,-?,-help    Displays the help screen

All pathnames will be processed in the order they are entered on the
command line.  you may abort the program at any time by pressing ESC.  NesToy
will stop on the ROM it is at and then quit.  You can add command line
parameters, including pathnames, to the NESTOY.CFG file.


NESTOY.CFG
----------
You can adjust where NesToy will move your ROMs to when (-sort) is used with
the following entries.  Default entries are shown.

  DIR_BASE =
  DIR_BACKUP = Backup\          DIR_MAPHACKS = Mapper Hacks\
  DIR_BAD = Bad\                DIR_UNLICENSED = Unlicensed\
  DIR_CANADA = Canada\          DIR_PIRATE = Pirate\
  DIR_CHINA = China\            DIR_SWEDEN = Sweden\
  DIR_DUPLICATES = Dupes\       DIR_TRANS = Translated\
  DIR_EUROPE = Europe\          DIR_UNKNOWN = Unknown\
  DIR_GAMEHACKS = Game Hacks\   DIR_UNLICENSED = Unlicensed\
  DIR_HACKED = Hacked\          DIR_USA = USA\
  DIR_JAPAN = Japan\            DIR_VS = VS Unisystem\

DIR_BASE sets the base directory all the other directories will fall under.
If DIR_BASE is left empty, the base directory will default to the current
directory you run NesToy from.  DIR_BASE will only affect relative pathnames.
For example, if DIR_BASE is set to C:\ROMS\ and DIR_USA is set to USA\, then
DIR_USA will be expanded to C:\ROMS\USA\.  However, if DIR_USA is set to
something similar to C:\ROMS2\USA\, it will not be affected by DIR_BASE.

DIR_SAVESTATES should be set to your battery backup/savestate directory.
When renaming ROMs, NesToy will automatically rename any matching .SAV and
.ST* files it finds in this directory.  Leaving this entry empty will
disable this feature.

The following settings determine where NesToy will move bad dumps, pirates,
and hacks when (-sort) is used.  If set to TRUE, bad dumps will be moved
into the DIR_BAD directory, pirates will be moved into the DIR_PIRATE
directory, and hacks will be moved into the appropriate hack diretctory 
(DIR_GAMEHACKS, DIR_HACKED, or DIR_MAPHACKS.) If set to FALSE, roms will be
moved into their corresponding country directory instead.

  MOVE_BAD = TRUE
  MOVE_HACKED = TRUE
  MOVE_PIRATE = TRUE

The following settings determine what NesToy will include in the missing.txt
file when (-missing) is used.  A setting of TRUE means ROMs of that type
will be included in the missing list.  If set to FALSE, roms of that type
will not be included.

  MISSING_BAD = FALSE
  MISSING_GAMEHACKS = FALSE
  MISSING_HACKED = TRUE
  MISSING_PIRATE = TRUE
  MISSING_TRANS = FALSE

The following setting determines whether shorter names will be used for some
game titles. (Example: if set to TRUE, instead of "Zelda 2 - The Adventure of
Link.nes", the ROM will just be named "Zelda 2.nes")

  SHORT_NAMES = FALSE


You can place command line parameters here and they will be used every time
you run NesToy.  Parameters on the command line always have priority over
those listed here.

CMDLINE =


Output
------
* Zelda 2 - The Adventure of Link.nes       1 HB..  128kB  128kB  U  ba322865
|                 |                         | ||||    |      |    |     |
1                 2                         3 4567    8      9   10    11

 1 - ROM Status
     * - ROM is identified and good.
     ? - Unknown ROM
     x - ROM is identified, but something is wrong with it.
         Use -i for more information.
     d - ROM is a duplicate
     n - Name does not match ROM name in database
     b - ROM is a bad dump
 2 - File Name
 3 - Mapper #
 4 - Mirroring (H- Horizontal, V- Vertical)
 5 - Battery (SRAM)
 6 - Trainer Present
 7 - 4-Screen Buffer
 8 - Size of Program ROM (PRG)
 9 - Size of Character ROM (CHR)
10 - Country Code
       J - Japan      S - Sweden
       U - USA       Unl- Unlicensed
       E - Europe    TR - Translated
       C - Canada    ???- Unknown
     (May also contain: P10 - Playchoice-10, or VS - VS. Unisystem)
11 - Checksum (CRC-32)

If (-c) is not used, 1, 10, and 11 will not be displayed.


Known issues
------------
* Enabling Windows 2000 support in NESTOY.CFG and then trying to run NesToy
  under DOS or Windows NT may cause file corruption.  DO NOT DO IT.

* When using (-sub), NesToy only scans one level deep.  This should be
  sufficient for most everybody.

* If you do not create a new missing file with each new release, any database
  additions made will not show up on the list.

* Translations, game hacks, and bad dumps are not included by default in the
  missing ROMs listing.  You must set the appropriate options in the
  NESTOY.CFG to TRUE and then create a new missing list for these to show up.

* Bad Dumps automatically detected by NesToy that are not in the database
  will never show up on the missing list.  NesToy uses several methods to
  identify corrupt ROMs, even if they are unknown to NesToy.

* Game Hacks not in NesToy's database may be flagged as (Bad CHR).  Please
  submit these to digitoxin@mindspring.com so that I may add them to
  NesToy's database.  

* When NesToy is moving and/or renaming a ROM, sometimes it encounters a ROM
  already there with the same name.  NesToy will first try to attach a
  country code to the ROM it is moving to differentiate it.  If that fails,
  NesToy will be unable to move/rename the ROM.  You will usually encounter
  this if you are using the same directory to store Japanese and USA ROMs or
  if you have unknown or misplaced ROMs in the destination directory.

* Remember, even though NesToy -doall invokes the default settings for
  (-missing) and (-ren), you can still specify your own settings for these
  options on the command line or in the nestoy.cfg file.
  Example: NesToy -doall -renc will rename all your ROMs with country codes
  attached while still performing all the other options invoked by (-doall)
  normally.

* NesToy has an internal limit of 3500 files per directory.  If you have
  more than 3500 files in a directory, NesToy will only process up to the
  3500th file.  If you have NesToy set to sort the ROMs it processes into
  different directories, you can just run NesToy again to process the
  remaining ROMs.


Differences between Pirates and Hacks
-------------------------------------
A pirated ROM is a ROM where the title and/or copyright information has been
altered, defaced, or removed.  If anything else has modified in the ROM, then
it is considered a hack.  NesToy defines 3 different types of hacks.

  Mapper Hack - The ROM has been hacked to run under a different mapper.
  Game Hack   - The games graphics and/or program code has been significantly
                modified to change the look and gameplay of the game.
                Examples are the countless Super Mario Bros. hacks that exist
                on the web.
  Other Hacks - Any other type of hack that is not a pirate and does not fit
                in one of the above categories.  Trained ROMs fall into this
                category.


Mapper Information
------------------
Games using the following mappers control the mirroring directly and do
not use the mirroring bit in the header.  Therefore, for these mappers, the
mirroring bit has been set to 'H' or more appropriately, off.  There may be
more, but these are the ones I am sure of.

     1,5,7,9,10,16,18,21,22,23,24,25,32,33,64,65,66,68,69

Mapper 4 also controls the mirroring directly, but there are several
mapper 4 games which do not seem to set the mirroring correctly when loaded.
Therefore, all mapper 4 games have the mirroring bit set to the mirroring
they start up in to ensure all emulators display these games correctly.

There are several games set to mapper 118 that were previously set to mapper
4.  Mapper 118 seems to be similar to mapper 4, and although these games
never worked right under mapper 4 in any emulator, they do work when set to
mapper 118 in Famstasia which seems to emulate this mapper the best.  FwNES
also emulates mapper 118 partially.  Mapper 118 may not be the correct
mapper for these games, but currently they work best under this mapper.
These games are listed below.

  Alien Syndrome (U)
  Arumajiro (J)
  Goal! Two (U)
  Goal! Two (E)
  NES Play Action Football (U)
  Pro Sport Hockey (U)
  Ys 3 - Wanderers From Ys (J)

About bad dumps
---------------
Valid PRG sizes:   16,32,64,128,256,512,640,1024,1536,2048
Valid CHR sizes: 8,16,32,64,128,256,512,1024

If you have a ROM with values other than those listed above, it is a bad
dump.  Check the ROM list distributed with NesToy to see what the correct
size for the ROM is.  NesToy will detect these ROMs and mark them as bad.

Dragon Warrior 4 (Wrong Size)               1 HB.. 1024kB  -----  U  41413b06

This ROM is the wrong size.  The correct Dragon Warrior 4 ROM is 512kb, but
you may want to hold onto this one because Nesticle won't run the correct
ROM, but it plays this one fine.  NesToy cannot resize the 1024kb version of
this ROM to 512kb because of the unusual way data is duplicated in the ROM.
