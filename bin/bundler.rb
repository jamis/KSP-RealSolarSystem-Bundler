if ARGV.include?("--ui")
  require 'ksp/rss/ui'
  ui = KSP::RSS::UI.new
  while ui.isVisible
    Thread.pass
  end
  puts "done?"

else
  require 'ksp/rss/settings'
  settings = KSP::RSS::Settings.new
  settings.build
end
