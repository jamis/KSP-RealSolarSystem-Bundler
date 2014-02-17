require 'yaml'
require 'shellwords'

page_size = (ARGV.first || 10).to_i
puts "URLs will be opened in sets of #{page_size}"

mods = YAML.load_file("master.yml")
urls = mods.map { |m| Shellwords.shellescape(m['home']) }

(0..urls.length-1).step(page_size) do |n|
  subset = urls[n,page_size]
  system "open #{subset.join(' ')}"

  remaining = urls.length - (n + page_size)

  if remaining > 0
    puts "#{remaining} urls remaining to display..."
    puts "Press return to continue"
    gets
  end
end
