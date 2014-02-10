require 'ksp/rss/ui'

ui = KSP::RSS::UI.new
while ui.isVisible
  Thread.pass
end
