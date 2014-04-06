require 'ksp/rss/ui'

java.lang.System.setProperty "jsse.enableSNIExtension", "false"

ui = KSP::RSS::UI.new(*ARGV)
while ui.isVisible
  Thread.pass
end
