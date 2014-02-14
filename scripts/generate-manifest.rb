require 'yaml'

template = YAML.load_file(ARGV.first)
master = YAML.load_file("master.yml")
master_map = master.inject({}) { |h, mod| h[mod['name']] = mod; h }

def all_required(mod, mapping)
  list = [mod['name']]

  (mod['requires'] || []).each do |n|
    list.concat(all_required(mapping[n], mapping))
  end

  list
end

def incompatible?(mod1, mod2)
  (mod1['incompatible'] || []).include?(mod2['name']) ||
    (mod2['incompatible'] || []).include?(mod1['name'])
end

output = {
  'bundle' => template['bundle'],
  'archive' => template['archive'],
  'version' => template['version']
}

%w{required recommended defaults}.each do |section|
  output[section] = template[section]
end

warn "building dependency graph"
requirements = master.inject({}) do |h,mod|
  h[mod['name']] = all_required(mod, master_map)
  h
end

required = (template['required'] || []).map { |m| requirements[m] }.flatten.uniq

# A is incompatible with B if B is in A's incompatible list
# A is incompatible with B if A is in B's incompatible list
# A is incompatible with B if B requires a mod that is incompatible with A
# A is incompatible with the bundle if it is listed as 'unsupported'

warn "testing for module compatibility..."
incompatible = master.select do |mod|
  required.any? do |rmod|
    requirements[mod['name']].any? do |mod2|
      incompatible?(master_map[rmod], master_map[mod2])
    end
  end
end

# unsupported = explicitly unsupported, or anything that requires something that
#   is unsupported

unsupported = (template['unsupported'] || {}).keys
unsupported.concat(master.select { |mod| unsupported.any? { |u| requirements[mod['name']].include?(u) } }.map { |m| m['name'] }).uniq!

unsupported += incompatible.map { |m| m['name'] }

output['mods'] = master.reject { |mod| unsupported.include?(mod['name']) }

puts output.to_yaml
