require 'ksp/rss/ui'

ui = KSP::RSS::UI.new(*ARGV)
while ui.isVisible
  Thread.pass
end
