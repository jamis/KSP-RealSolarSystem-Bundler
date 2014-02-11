require 'yaml'
require 'uri'
require 'open-uri'
require 'ksp/rss/module'

module KSP
  module RSS
    class Manifest
      DEFAULT_URI = URI.parse("https://raw.github.com/jamis/KSP-RealSolarSystem-Bundler/master/real-solar-system.manifest")

      attr_reader :bundle, :archive, :version
      attr_reader :required, :recommended, :configure, :defaults
      attr_reader :mods, :categories

      def initialize(uri=nil)
        uri ||= DEFAULT_URI

        begin
          contents = open(uri)
          @data = YAML.load(contents)
        rescue Exception => e
          puts "error opening #{uri}: #{e.class} (#{e.message})"
          @data = {}
        end

        @bundle = @data['bundle']
        @archive = @data['archive']
        @version = @data['version']

        @required = @data['required'] || []
        @recommended = @data['recommended'] || []
        @configure = @data['configure'] || []
        @defaults = @data['defaults'] || []

        @mod_map = (@data['mods'] || []).inject({}) do |h, d|
          mod = KSP::RSS::Module.new(d)
          mod.required = @required.include?(mod.name)
          mod.recommended = @recommended.include?(mod.name)
          h[mod.name] = mod
          h
        end

        @mods = @mod_map.keys.sort

        @category_map = @mod_map.inject({}) do |h,(name,mod)|
          h[mod.category] ||= []
          h[mod.category] << name
          h
        end

        @categories = @category_map.keys.sort
      end

      def category(name)
        @category_map[name]
      end

      def [](name)
        @mod_map[name]
      end

      def each
        @mods.each do |name|
          yield @mod_map[name]
        end
      end
    end
  end
end
