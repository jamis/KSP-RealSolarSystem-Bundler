require 'ksp/rss/modlist'
require 'shellwords'

require './jars/zip4j_1.3.2.jar'

module KSP
  module RSS
    class Settings
      DEFAULTS = %w(
        --aies
        --alarm
        --chutes
        --dre
        --far
        --kas
        --kjr
        --kw
        --mce
        --mj
        --novapunch
        --pf
        --rf
        --rfts
        --rla
        --rov
        --rpl
        --stretchy
        --tac
        --visual
      )

      STOCKISH = %w(
        --aies
        --alarm
        --dre
        --far
        --kas
        --kjr
        --kw
        --mj
        --novapunch
        --pf
        --rfts
        --rla
        --stretchy
        --tac
        --visual
      )

      attr_reader :args
      attr_reader :mod_list

      def initialize(args=ARGV)
        @args = args.dup

        source = extract_mod_source
        @mod_list = KSP::RSS::ModList.load_list(source)
        process_args!
      end

      def build
        @mod_list.each { |m| m.download(self)   }
        @mod_list.each { |m| m.unpack(self)     }
        @mod_list.each { |m| m.build(self)      }
        @mod_list.each { |m| m.post_build(self) }
      end

      def say(message)
        puts message
      end

      def warn_and_abort(message)
        puts "---------------"
        puts message
        exit 1
      end

      private

        def extract_mod_source
          if @args.detect { |d| d =~ /^--source=(.*)/ }
            source = $1
            if source =~ /^(ht|f)tps?:/
              return URI.parse(source)
            else
              return source
            end
          end

          nil
        end

        def show_help
          puts "%20s %s" % ["-l|--list", "list all mods"]
          puts "%20s %s" % ["--urls", "open all URLs in a browser window"]
          puts "%20s %s" % ["--describe", "dump a BBCode-formatted list"]
          puts "%20s %s" % ["--zip", "create an archive from an existing build directory"]
          puts "%20s %s" % ["--all", "force all mods to be selected"]
          puts "%20s %s" % ["--source=[file|url]", "specify an alternative location for the mod dependency file"]
          puts

          @mod_list.each do |m|
            next if m.disabled? || !m.optional?
            puts "%20s %s" % [m.option, m]
          end

          puts
          puts "%20s %s" % ["--defaults", "a sane default set of options (#{DEFAULTS.join(' ')})"]
          puts "%20s %s" % ["--stockish", "Play RSS with stock fuels (#{STOCKISH.join(' ')})"]
          puts
          puts "You may specify \"--no-[option]\" to specify that a mod should NOT be used"
        end

        def list_mods
          @mod_list.each do |m|
            print m
            print ": #{m.option}" if m.optional?
            print " (disabled)" if m.disabled?
            puts
          end
        end

        def open_urls
          urls = Shellwords.join(@mod_list.map { |m| m.url })
          system("open -a Google\\ Chrome #{urls}")
        end

        def describe_mods
          categories = @mod_list.group_by { |m| m.category }
          %w(core extra part utility interesting support).each do |cat|
            puts "[b]#{cat} mods[/b]"
            puts "[list]"
            categories[cat].each do |mod|
              puts "[*]#{mod.name} - [url]#{mod.url}[/url]"
            end
            puts "[/list]"
          end
        end

        def create_zip
          puts "archiving..."

          zipfile = Java::NetLingalaZip4jCore::ZipFile.new("HardMode.zip")
          parameters = Java::NetLingalaZip4jModel::ZipParameters.new
          constants = Java::NetLingalaZip4jUtil::Zip4jConstants

          parameters.setCompressionMethod(constants.COMP_DEFLATE)
          parameters.setCompressionLevel(constants.DEFLATE_LEVEL_ULTRA)

          Dir["build/*"].each do |n|
            zipfile.addFolder(n, parameters)
          end

          puts "finished -- created HardMode.zip"
        end

        def process_args!
          if @args.empty? || @args.include?("-h") || @args.include?("--help")
            show_help
            exit 1
          elsif @args.include?("-l") || @args.include?("--list")
            list_mods
            exit 1
          elsif @args.include?("--urls")
            open_urls
            exit 1
          elsif @args.include?("--describe")
            describe_mods
            exit 1
          elsif @args.include?("--zip")
            create_zip
            exit 1
          elsif (defaults_index = @args.index("--defaults"))
            @args[defaults_index,1] = DEFAULTS
          elsif (stockish_index = @args.index("--stockish"))
            @args[stockish_index,1] = STOCKISH
          end

          omits = []
          @args.each do |a|
            omits << "--#{$1}" if a =~ /--no-(.*)/
          end

          @args = @args - omits

          unless @args.include?("--all")
            @mod_list = @mod_list.reject do |mod|
              mod.disabled? ||
                (mod.optional? && !args.include?(mod.option))
            end
          end
      end
    end
  end
end
