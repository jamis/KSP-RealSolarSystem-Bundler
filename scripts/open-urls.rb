require 'yaml'
require 'shellwords'

mods = YAML.load_file("master.yml")
urls = mods.map { |m| Shellwords.shellescape(m['home']) }

system "open #{urls.join(' ')}"
