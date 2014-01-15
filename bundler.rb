require 'yaml'
require 'fileutils'
require 'uri'
require 'open-uri'
require 'cgi'
require 'net/http'
require 'net/https'
require 'shellwords'

class KSPMod
  SPACEPORT_URL = URI.parse("http://kerbalspaceport.com/wp/wp-admin/admin-ajax.php")
  GAMEDATA_PATH = File.join("build", "GameData")
  SHIPS_PATH = File.join("build", "Ships")
  SOURCE_PATH = File.join("build", "Source")
  SUBASSEMBLIES_PATH = File.join("build", "Subassemblies")

  def initialize(data)
    @data = data
  end

  def file_name
    case @data['via']
      when 'forum'
        @data['file']
      when 'spaceport'
        "%s.%s" % [@data['addonid'], @data['type']]
      when 'direct'
        File.basename(@data['download'])
      else
        raise NotImplementedError, "mod must be via forum or spaceport"
    end
  end

  def cached_path
    File.join("cache", file_name)
  end

  def unpacked_path
    File.join("unpacked", file_name)
  end

  def cached?
    File.exists?(cached_path)
  end

  def unpacked?
    File.exists?(unpacked_path)
  end

  def to_s
    "#{@data['name']} #{@data['version']}"
  end

  def download
    if cached?
      puts " -- cached: #{self}"
      return
    end

    puts "downloading #{self}"
    FileUtils.mkdir_p(File.dirname(cached_path))
    send :"download_via_#{@data['via']}"
  end

  def unpack
    if unpacked?
      puts " -- already unpacked: #{self}"
      return
    end

    puts "unpacking #{self}"
    FileUtils.mkdir_p(unpacked_path)

    case File.extname(file_name).downcase
      when ".rar" then unpack_rar
      when ".zip" then unpack_zip
      when ".cfg" then unpack_raw
      else
        raise "unsupported file type: #{file_name} (#{self})"
    end
  end

  def disabled?
    @data['disabled']
  end

  def optional?
    @data['option']
  end

  def option
    @data['option']
  end

  def skip?
    disabled? ||
      (optional? && !ARGV.include?(option))
  end

  def build(from=unpacked_path)
    FileUtils.mkdir_p(GAMEDATA_PATH)
    FileUtils.mkdir_p(SHIPS_PATH)
    FileUtils.mkdir_p(SOURCE_PATH)
    FileUtils.mkdir_p(SUBASSEMBLIES_PATH)

    if @data['gamedata']
      build_gamedata_dir(from)
    else
      contents = Dir["#{from}/*"]
      docs = []
      gamedata_dir = nil

      contents.each do |item|
        case File.basename(item)
          when /read|copy|license/i then
            docs << item
          when "GameData" then
            gamedata_dir = build_gamedata_dir(item)
          when "Ships" then
            build_ships_dir(item)
          when "Subassemblies" then
            build_subassemblies_dir(item)
          when "Source" then
            build_source_dir(item)
          else
            if File.directory?(item)
              gamedata_dir ||= build(item)
            else
              warn "junk file: #{item}"
            end
        end
      end

      if gamedata_dir && docs.any?
        docs.each { |d| FileUtils.cp(d, gamedata_dir) }
      end

      gamedata_dir
    end
  end

  def find_gamedata(root=unpacked_path)
    Dir["#{root}/*"].each do |item|
      next if ignore?(item) || !File.directory?(item)
      result = File.basename(item) == "GameData" ? item : find_gamedata(item)
      return result if result
    end

    nil
  end

  def post_build
    return unless @data['post-build']

    src_gamedata = find_gamedata || "(no gamedata dir)"
    script = @data['post-build'].
      gsub(/\$SRC_GAMEDATA/, src_gamedata).
      gsub(/\$SRC/, unpacked_path).
      gsub(/\$GAMEDATA/, GAMEDATA_PATH)

    system(script) or abort "could not run post-build for #{self}"
  end

  private

    def download_via_forum
      uri = URI.parse(@data['url'])
      page = uri.read
      url = page[/href="([^"]*?#{Regexp.escape(@data['file'])}.*?)"/, 1]
      abort "download path is nil for #{@data['name']}" unless url

      url = CGI.unescapeHTML(url)
      if url =~ /dropbox\./
        download_via_dropbox(url)
      elsif url =~ /mediafire/
        download_via_mediafire(url)
      else
        download_url(url)
      end
    end

    def download_via_spaceport
      response = Net::HTTP.start(SPACEPORT_URL.host, SPACEPORT_URL.port) do |http|
        request = Net::HTTP::Post.new(SPACEPORT_URL)
        request.set_form_data 'addonid' => @data['addonid'], 'action' => 'downloadfileaddon'
        request['X-Requested-With'] = "XMLHttpRequest"

        http.request(request)
      end

      location = response.body
      download_url(location)
    end

    def download_via_direct
      download_url(@data['download'])
    end

    def download_via_dropbox(url)
      uri = URI.parse(url)
      page = uri.read
      url = page[/href="([^"]*?#{Regexp.escape(@data['file'])}.*?)"/, 1]
      abort "dropbox url is nil for #{@data['name']}" unless url

      url = CGI.unescapeHTML(url)
      download_url(url)
    end

    def download_via_mediafire(url)
      uri = URI.parse(url)
      page = uri.read
      url = page[/kNO\s*=\s*"([^"]*?#{Regexp.escape(@data['file'])}.*?)"/, 1]
      abort "mediafire url is nil for #{@data['name']}" unless url

      url = CGI.unescapeHTML(url)
      download_url(url)
    end

    def download_url(url, redirects=0)
      raise "#{@data['name']} redirected too many times" if redirects > 5

      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)

      case response
      when Net::HTTPRedirection
        new_location = response['Location']
        download_url(new_location, redirects+1)

      when Net::HTTPSuccess
        File.open(cached_path, "w") do |out|
          out.write(response.body)
        end
      else
        raise "#{@data['name']}: #{response.code} #{response.message}"
      end
    end

    def unpack_rar
      command = Shellwords.join(["unrar", "x", "../../#{cached_path}"])
      Dir.chdir(unpacked_path) do
        if !system(command)
          raise "could not unpack #{self} (#{cached_path})"
        end
      end
    end

    def unpack_zip
      command = Shellwords.join(["unzip", "-q", cached_path, "-d", unpacked_path])
      if !system(command)
        raise "could not unpack #{self} (#{cached_path})"
      end
    end

    def unpack_raw
      FileUtils.cp(cached_path, unpacked_path)
    end

    def build_gamedata_dir(source)
      deep_copy source, GAMEDATA_PATH
    end

    def build_ships_dir(source)
      deep_copy source, SHIPS_PATH
    end

    def build_subassemblies_dir(source)
      deep_copy source, SUBASSEMBLIES_PATH
    end

    def build_source_dir(source)
      sanitized_name = @data['name'].downcase.gsub(/ /, "_").gsub(/[\(\)]/, "")
      dest_dir = File.join(SOURCE_PATH, sanitized_name)
      FileUtils.mkdir_p(dest_dir)
      deep_copy(source, dest_dir)
    end

    def ignore?(item)
      (@data['ignore'] || []).any? { |i| item.include?(i) }
    end

    def deep_copy(source_root, dest_root, source=source_root)
      result = nil

      prefix_size = source_root.length + 1
      Dir["#{source}/*"].each do |item|
        next if ignore?(item)
        relative_name = item[prefix_size..-1]

        if File.directory?(item)
          dest_path = File.join(dest_root, relative_name)
          result ||= dest_path
          FileUtils.mkdir_p(dest_path)
          deep_copy(source_root, dest_root, item)
        else
          FileUtils.cp(item, File.join(dest_root, relative_name))
        end
      end

      result
    end
end

data = YAML.load_file("mods.yml")
mods = data.map { |d| KSPMod.new(d) }

if ARGV.include?("-h") || ARGV.include?("--help")
  puts "%20s %s" % ["-l|--list", "list all mods"]
  puts

  mods.each do |m|
    next if m.disabled? || !m.optional?
    puts "%20s %s" % [m.option, m]
  end
  exit
elsif ARGV.include?("-l") || ARGV.include?("--list")
  mods.each do |m|
    print m
    print ": #{m.option}" if m.optional?
    print " (disabled)" if m.disabled?
    puts
  end
  exit
elsif ARGV.include?("--defaults")
  ARGV.replace(%w(--tac --kas --kw --rla --mj --crew-manifest --alarm))
end

mods = mods.reject { |m| m.skip? } unless ARGV.include?("--all")

mods.each { |m| m.download }
mods.each { |m| m.unpack }
mods.each { |m| m.build }
mods.each { |m| m.post_build }

if ARGV.include?("--zip")
  puts "bundling..."
  Dir.chdir("build") do
    system "zip -r9 ../HardMode.zip *"
  end
end
