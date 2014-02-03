Real Solar System Bundler
===========================

"Real Solar System" (RSS) is a mod for Kerbal Space Program (KSP) that changes the default solar system to mimic the "real" Solar System. It is recommended to use it with a whole host of other mods, which increase the realism of the game further, but as a result it becomes increasingly complicated to set up. In fact, because there are so many different ways to configure the various mods, it is quite difficult even to instruct others how to set it up!

This script is an attempt to "canonicalize" a set of defaults for setting up RSS. These defaults are based on my own preferences, but they form a decent starting point for others who are curious about the mod, and the defaults are easily tweaked if you prefer different settings.

Because this was written for my own use, it is in very rough form. If that bothers you, pull-requests are welcome. :)

Installation
------------

You'll need to make sure the following utilities are installed:

* JRuby (http://jruby.org)
* warble (Ruby gem, `gem install warble`)
* unzip
* unrar

Usage
-----

At it's simplest, you can just run the following command:

    ruby bundler.rb --ui

This presents you with a GUI for selecting mods, and for building the `HardMode.zip` file.

If you want more control, you can pass other options to the script instead:

    ruby bundler.rb --defaults

This will skip the GUI and just grab all the default mods, downloading them, unpacking them, and then installing them into a `build` directory wherever you run the script. The build directory contains a KSP GameData folder, as well as folders for source code, ships, and so forth.

Once that `build` directory is ready, you can copy it into your KSP folder. Or, you can zip it all up:

    ruby bundler.rb --zip

This will create a file named `HardMode.zip` in the current directory. You can then copy that to your KSP folder, and unzip it.

If you want to choose which mods you want, you can specify them on the command-line instead of giving the "--defaults" argument. To see which options are supported, just type:

    ruby bundler.rb --help

