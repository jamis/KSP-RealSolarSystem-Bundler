Real Solar System
=================

"Real Solar System" (RSS) is a mod for Kerbal Space Program (KSP) that changes the default solar system to mimic the "real" Solar System. It is recommended to use it with a whole host of other mods, which increase the realism of the game further, but as a result it becomes increasingly complicated to set up. In fact, because there are so many different ways to configure the various mods, it is quite difficult even to instruct others how to set it up!

This program is an attempt to "canonicalize" a set of defaults for setting up RSS. These defaults are based on my own preferences, but they form a decent starting point for others who are curious about the mod, and the defaults are easily tweaked if you prefer different settings.


Requirements
------------

You'll need Java installed. Most systems do, by default, but if yours doesn't have it, you'll need to download and install it.


Usage
-----

Just run the "real-solar-system" script. On Windows, you'll want to run "real-solar-system.bat". On Linux or Mac, run "real-solar-system.sh" instead.

The manifest for the "Real Solar System" bundle will be downloaded each time you run it (though you can download the manifest file and tweak it, and then open it manually via the "File" menu, if you need to.) Choose which mods you want (a sensible set of defaults are pre-selected). Then, click the "built it" button.

This will download the various mods, unpack them, and then install them into a `build` directory wherever you put the script. The build directory contains a KSP GameData folder, as well as folders for source code, ships, and so forth.

Once finished setting up that `build` directory, it will then zip it up into a zip file. (The default will be about 180MB in size, but depending on any customizations you make, it could be larger or smaller.)

Copy that new zip file to your KSP installation directory, and unzip it.

That's all!


Credits
-------

This script was put together by Jamis Buck (jamis@jamisbuck.org).

The Real Solar System mod itself is by NathanKell. All mods are distributed by their respective authors.
