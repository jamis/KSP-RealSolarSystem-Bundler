Real Solar System
=================

"Real Solar System" (RSS) is a mod for Kerbal Space Program (KSP) that changes the default solar system to mimic the "real" Solar System. It is recommended to use it with a whole host of other mods, which increase the realism of the game further, but as a result it becomes increasingly complicated to set up. In fact, because there are so many different ways to configure the various mods, it is quite difficult even to instruct others how to set it up!

This script is an attempt to "canonicalize" a set of defaults for setting up RSS. These defaults are based on my own preferences, but they form a decent starting point for others who are curious about the mod, and the defaults are easily tweaked if you prefer different settings.


Requirements
------------

You'll need Java installed. Most systems do, by default, but if yours doesn't have it, you'll need to download and install it.


Usage
-----

First, you'll need to open a command prompt, and then navigate to the directory where you unzipped this utility.

On Windows, (assuming extracted the utility to your desktop), that might be something like this:

    cd "C:\Documents and Settings\Owner\Desktop\real-solar-system"

Then, run the included batch file:

    real-solar-system.bat --defaults

If you're on a Mac, or using Linux, you'll run the included shell file instead:

    ./real-solar-system.sh --defaults

This will download the various mods, unpack them, and then install them into a `build` directory wherever you run the script. The build directory contains a KSP GameData folder, as well as folders for source code, ships, and so forth.

Once finished setting up that `build` directory, it will then zip it up into a `HardMode.zip` file. (The default will be about 180MB in size, but depending on any customizations you make, it could be larger or smaller.)

Copy that `HardMode.zip` file to your KSP installation directory, and unzip it.

That's all!


Advanced Usage
--------------

If you want to choose which mods you want, you can specify them on the command-line instead of giving the "--defaults" argument. To see which options are supported, just type:

    real-solar-system.bat --help

Or, if you want the defaults, but want to tweak it a little bit, you can just add the other arguments with the "--defaults" argument:

    real-solar-system.bat --defaults --soviet --no-remote


Credits
-------

This script was put together by Jamis Buck (jamis@jamisbuck.org).

The Real Solar System mod itself is by NathanKell. All mods are distributed by their respective authors.
