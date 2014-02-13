require 'yaml'

manifest = YAML.load_file("real-solar-system.manifest")
mods = manifest['mods']

catmap = mods.group_by { |m| m['category'] }
categories = catmap.keys.sort

categories.each do |category|
  puts "[b]#{category} mods[/b]"
  puts
  puts "[list]"

  catmap[category].sort_by { |m| m['name'] }.each do |mod|
    if mod.fetch('visible', true)
      puts "[*] #{mod['name']} - [url]#{mod['home']}[/url]"
    end
  end

  puts "[/list]"
  puts
end
