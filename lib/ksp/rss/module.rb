require 'fileutils'
require 'uri'
require 'open-uri'
require 'cgi'
require 'net/http'
require 'net/https'
require 'shellwords'
require 'strscan'

require 'ksp/rss/configuration'

require './jars/zip4j_1.3.2.jar'

# hack, and not very safe
# TODO: find a safer way to allow open-uri to redirect HTTP->HTTPS
def OpenURI.redirectable?(uri1, uri2)
  true
end

module KSP
  module RSS
    class Module
      SPACEPORT_URL = URI.parse("http://kerbalspaceport.com/wp/wp-admin/admin-ajax.php")
      GAMEDATA_PATH = File.join("build", "GameData")
      SHIPS_PATH = File.join("build", "Ships")
      SOURCE_PATH = File.join("build", "Source")
      SUBASSEMBLIES_PATH = File.join("build", "Subassemblies")

      attr_reader :version, :requires, :category, :name, :home, :incompatible
      attr_reader :description

      def initialize(data)
        @data = data

        @version = data['version']
        @requires = data['requires']
        @category = data['category']
        @name = data['name']
        @home = data['home']
        @incompatible = data['incompatible'] || []
        @description = data['description']
      end

      def type
        if @data['type']
          @data['type']
        elsif @data['url']
          File.extname(@data['url'])[1..-1]
        else
          nil
        end
      end

      def uri
        @uri ||= URI.parse(@data['url'])
      end

      def file_name
        @file_name ||= begin
          if @data['file']
            @data['file']
          elsif @data['url']
            File.basename(uri.path)
          else
            normalized = @data['name'].downcase.gsub(/\W/, "")
            normalized << '-' << version.to_s if version
            normalized << ".#{type}" if type
            normalized
          end
        end
      end

      def recommended=(r)
        @recommended = r
      end

      def recommended?
        @recommended
      end

      def required=(r)
        @required = r
      end

      def required?
        @required
      end

      def compatible_with?(mod)
        !incompatible.include?(mod.name) &&
          !mod.incompatible.include?(self.name)
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

      def build?
        @data.fetch('build', true)
      end

      def visible?
        @data.fetch('visible', true)
      end

      def unpacked?
        File.exists?(unpacked_path)
      end

      def to_s
        "#{name} #{version}"
      end

      def download(reporter)
        if cached?
          reporter.say " -- cached: #{self}"
          return
        end

        reporter.say "downloading #{self}"
        FileUtils.mkdir_p(File.dirname(cached_path))
        send :"download_via_#{@data['via']}", reporter
      end

      def unpack(reporter)
        if unpacked?
          reporter.say " -- already unpacked: #{self}"
          return
        end

        reporter.say "unpacking #{self}"
        FileUtils.mkdir_p(unpacked_path)

        case File.extname(file_name).downcase
          when ".rar" then unpack_rar
          when ".zip" then unpack_zip
          when ".cfg", ".dll" then unpack_raw
          else
            raise "unsupported file type: #{file_name} (#{self})"
        end
      end

      def build(reporter, from=unpacked_path)
        return unless build?

        FileUtils.mkdir_p(GAMEDATA_PATH)
        FileUtils.mkdir_p(SHIPS_PATH)
        FileUtils.mkdir_p(SOURCE_PATH)
        FileUtils.mkdir_p(SUBASSEMBLIES_PATH)

        if @data['gamedata']
          build_gamedata_dir(from)
        else
          contents = Dir[File.join(from, "*")]
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
                  gamedata_dir ||= build(reporter, item)
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
        Dir[File.join(root, "*")].each do |item|
          next if ignore?(item) || !File.directory?(item)
          result = File.basename(item) == "GameData" ? item : find_gamedata(item)
          return result if result
        end

        nil
      end

      def install(siblings)
        (@data['install'] || []).each do |set|
          if set['when']
            matches = siblings & set['when']
            next unless matches.length == set['when'].length
          end

          set['actions'].each do |command|
            configure(command)
          end
        end
      end

      def configure(command)
        case command
          when /^DELETE (.*)/
            delete_file($1)
          when /^RMDIR (.*)/
            delete_folder($1)
          when /^MKDIR (.*)/
            make_folder($1)
          when /^COPY (.*)/
            source, target = $1.split(/ /, 2)
            copy_file(source, target)
          when /^REPLACE \/(.*?)\/(.*?)\/ (.*)/
            pattern = Regexp.new($1)
            replace = $2
            file = $3
            replace_in_file([[pattern, replace]], file)
          when /^REPLACEALL (.*?)\n(.*)/m
            file = $1
            patterns = $2.split(/\n/).map do |line|
              if line =~ /\/(.*?)\/(.*)\//
                [Regexp.new($1), $2]
              else
                raise "bad replaceall pattern: #{line.inspect}"
              end
            end
            replace_in_file(patterns, file)
          when /^RMMOD (\S+) (.*)/
            remove_module($1, $2)
          when /^APPENDMOD \"(.*?)\" (.*?)\n(.*)/m
            path = $1
            file = $2
            chunk = $3
            alter_module(file, path, chunk)
          when /^SETVALUES \"(.*?)\" (.*?)\n(.*)/m
            path = $1
            file = $2
            chunk = $3
            alter_module(file, path, chunk, true)
          else
            raise NotImplementedError, "unsupported configure command: #{command.inspect}"
        end
      end

      private

        def src_gamedata_path
          @src_gamedata_path ||= find_gamedata || "(no gamedata dir)"
        end

        def replace_substitutions(string)
          string.
            gsub(/\$SRC_GAMEDATA/, src_gamedata_path).
            gsub(/\$SRC/, unpacked_path).
            gsub(/\$GAMEDATA/, GAMEDATA_PATH)
        end

        def delete_file(file)
          file = replace_substitutions(file)
          Dir[file].each do |f|
            FileUtils.rm(f)
          end
        end

        def delete_folder(folder)
          folder = replace_substitutions(folder)
          FileUtils.rm_rf(folder)
        end

        def make_folder(folder)
          folder = replace_substitutions(folder)
          FileUtils.mkdir_p(folder)
        end

        def copy_file(source, target)
          source = replace_substitutions(source)
          target = replace_substitutions(target)

          Dir[source].each do |file|
            FileUtils.cp(file, target)
          end
        end

        def replace_in_file(patterns, file)
          file = replace_substitutions(file)
          contents = File.read(file, mode: "rt")

          patterns.each do |pattern, replace|
            contents = contents.gsub(pattern, replace)
          end

          File.open(file, "wt") { |f| f.write(contents) }
        end

        def remove_module(modname, file)
          file = replace_substitutions(file)

          config = Configuration.load_file(file)
          config.remove "* module", 'name' => modname

          File.open(file, "wt") { |f| f.write(config.to_s) }
        end

        def alter_module(file, path, chunk, overwrite=false)
          file = replace_substitutions(file)
          config = Configuration.load_file(file)

          path, conditions = path.split(/#/, 2)
          path ||= ""
          conditions = (conditions || "").split(/;/).inject({}) do |h, pair|
            k, v = pair.split(/=/)
            h[k] = v
            h
          end

          if overwrite
            config.set path, conditions, chunk
          else
            config.add path, conditions, chunk
          end

          File.open(file, "wt") { |f| f.write(config.to_s) }
        end

        def download_via_url(reporter)
          url = @data['url']

          if url =~ /dropbox\./
            download_via_dropbox(reporter, url)
          elsif url =~ /mediafire/
            download_via_mediafire(reporter, url)
          else
            download_url(reporter, url)
          end
        end

        def download_via_manual(reporter)
          cached = File.expand_path("cache")

          reporter.warn_and_abort <<MSG
Sadly, #{self} has to be downloaded manually
1. Go to: #{home}
2. Download #{file_name}
3. Move #{file_name} to the folder at #{cached}
4. Rerun this script to continue

Sorry for the inconvenience! Blame #{self}...
  they've selected an incompatible web host for their files
MSG
        end

        def download_via_spaceport(reporter)
          location = post_data(SPACEPORT_URL, 'addonid' => @data['addonid'], 'action' => 'downloadfileaddon')
          download_url(reporter, location)
        end

        def download_via_dropbox(reporter, url)
          uri = URI.parse(url)
          file = File.basename(uri.path)
          page = uri.read
          url = page[/href="([^"]*?#{Regexp.escape(file)}.*?)"/, 1]
          abort "dropbox url is nil for #{@data['name']}" unless url

          url = CGI.unescapeHTML(url)
          download_url(reporter, url)
        end

        def download_via_mediafire(reporter, url)
          uri = URI.parse(url)
          file = File.basename(uri.path)
          page = uri.read
          url = page[/kNO\s*=\s*"([^"]*?#{Regexp.escape(file)}.*?)"/, 1]
          abort "mediafire url is nil for #{@data['name']}" unless url

          url = CGI.unescapeHTML(url)
          download_url(reporter, url)
        end

        def download_url(reporter, url)
          result = open(URI.parse(url))
          File.open(cached_path, "wb") { |f| f.write(result.read) }
        end

        def unpack_rar
          command = Shellwords.join([File.join("..", "..", "commands", "unrar"), "x", File.join("..", "..", cached_path)])

          Dir.chdir(unpacked_path) do
            if !system(command)
              raise "could not unpack #{self} (#{cached_path})"
            end
          end
        end

        def unpack_zip
          zipfile = Java::NetLingalaZip4jCore::ZipFile.new(cached_path)
          zipfile.extractAll(unpacked_path)
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
          Dir[File.join(source, "*")].each do |item|
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

        def post_data(url, data)
          data = data.map { |name, value| "#{name}=#{value}" }.join("&")

          url = java.net.URL.new(url.to_s)
          connection = url.openConnection

          connection.setRequestMethod "POST"
          connection.setRequestProperty "Content-Type", "application/x-www-form-urlencoded"
          connection.setRequestProperty "X-Requested-With", "XMLHttpRequest"
          connection.setRequestProperty "Content-Length", data.length.to_s
          connection.setRequestProperty "Content-Language", "en-US"

          connection.setUseCaches false
          connection.setDoInput true
          connection.setDoOutput true

          out = java.io.DataOutputStream.new(connection.getOutputStream)
          out.writeBytes(data)
          out.flush
          out.close

          reader = java.io.BufferedReader.new(java.io.InputStreamReader.new(connection.getInputStream))
          response = ""

          while (line = reader.readLine)
            response << line
            response << "\n"
          end

          reader.close
          return response
        end
    end
  end
end
