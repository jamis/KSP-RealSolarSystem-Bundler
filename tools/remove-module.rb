require 'strscan'

def extract_block(scanner)
  block = "MODULE"

  block << scanner.scan(/\s*{\s*name\s*=\s*/)
  name = scanner.scan(/\w+/)
  block << name

  depth = 1
  while depth > 0
    block << scanner.scan(/[^{}]*/)
    bracket = scanner.scan(/[{}]/)
    block << bracket

    if bracket == "{"
      depth += 1
    elsif bracket == "}"
      depth -= 1
    end
  end

  { name: name, block: block }
end

cfg = ARGV[0]
mod = ARGV[1]

output = ""

scanner = StringScanner.new(File.read(cfg))
loop do
  prefix = scanner.scan_until(/^\s*MODULE\b/)
  if prefix.nil?
    output << scanner.rest
    break
  end

  output << prefix[0..-7]

  block = extract_block(scanner)
  output << block[:block] if block[:name] != mod
end

File.open(cfg, "w") { |f| f.write(output) }
