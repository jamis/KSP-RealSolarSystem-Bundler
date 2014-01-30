require 'yaml'
require 'uri'
require 'open-uri'
require 'ksp/rss/module'

module KSP
  module RSS
    class ModList < Array
      DATA_URI = URI.parse("https://raw.github.com/jamis/KSP-RealSolarSystem-Bundler/master/mods.yml")

      def self.load_list(uri=nil)
        uri ||= DATA_URI
        contents = open(uri)
        data = YAML.load(contents)
        new(data).map { |d| KSP::RSS::Module.new(d) }
      end
    end
  end
end
