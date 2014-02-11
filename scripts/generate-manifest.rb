require 'yaml'

template = YAML.load_file(ARGV.first)
master = YAML.load_file("master.yml")

output = {
  'bundle' => template['bundle'],
  'archive' => template['archive'],
  'version' => template['version']
}

%w{required recommended defaults configure}.each do |section|
  output[section] = template[section]
end

output['mods'] = master.select do |mod|
  !template['unsupported'].include?(mod['name'])
end

puts output.to_yaml
