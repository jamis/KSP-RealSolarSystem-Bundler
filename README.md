Real Solar System Bundler
===========================

"Real Solar System" (RSS) is a mod for Kerbal Space Program (KSP) that changes the default solar system to mimic the "real" Solar System. It is recommended to use it with a whole host of other mods, which increase the realism of the game further, but as a result it becomes increasingly complicated to set up. In fact, because there are so many different ways to configure the various mods, it is quite difficult even to instruct others how to set it up!

This script is an attempt to "canonicalize" a set of defaults for setting up RSS. These defaults are based on my own preferences, but they form a decent starting point for others who are curious about the mod, and the defaults are easily tweaked if you prefer different settings.

Pull-requests are welcome. :)

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

    ruby -Ilib bin/bundler.rb

This presents you with a GUI for selecting mods, and for building the archive. Once the archive is built, you can then copy that to your KSP folder, and unzip it.

Configuration
-------------

To add new mods, or edit the configuration of an existing mod, you'll need to look at the `master.yml` file. This is a YAML-formatted list of mods, with various options for each. The possible options are:

* `name` - the name of the mod (must be unique)
* `home` - this is the "home" URL of mod (usually a KSP forum thread, but doesn't have to be)
* `via` - how the mod is to be downloaded. This can be `url` (to specify a direct link to download it), `spaceport` (to specify that a mod is available via the KSP SpacePort site), and `manual` (when a mod cannot be automatically downloaded, for whatever reason).
* `addonid` - used when `via` is `spaceport`. The `addonid` identifies the mod to be downloaded (and you'll have to view the HTML source on SpacePort to find it).
* `version` - the current version of the mod
* `gamedata` - when `true`, the downloaded mod is intended to be unzipped directly into the GameData folder.
* `category` - the category this mod falls into (one of `core`, `extra`, `interesting`, `utility`, `support` or `part`)
* `incompatible` - a list of named mods that are incompatible with this mod, and which cannot be installed with it
* `ignore` - a list of patterns that identify files and directories that may be present in the mod's zip file, but which should be ignored when installing the mod.
* `requires` - a list of named mods that this mod requires, and which must be installed when this mod is

This `master.yml` file is then used in conjunction with manifest template files (see `real-solar-system.template` for an example). The template files define which mods are recommended, which are selected by default, as well as additional steps that should be taken to configure the mods once they are installed. To build a manifest from a template, run the `scripts/generate-manifest.rb` command:

    scripts/generate-manifest.rb real-solar-system.template > real-solar-system.manifest

In this way, you could theoretically create manifests for all sorts of different bundles, and not just for Real Solar System.
