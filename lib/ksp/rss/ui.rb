require 'fileutils'
require 'ksp/rss/manifest'
require './jars/zip4j_1.3.2.jar'

include Java

import java.awt.Dimension
import java.awt.Color
import java.awt.BorderLayout
import java.awt.Font
import javax.swing.JButton
import javax.swing.JCheckBox
import javax.swing.SwingConstants
import javax.swing.JFrame
import javax.swing.JLabel
import javax.swing.JTextArea
import javax.swing.JProgressBar
import javax.swing.BorderFactory
import javax.swing.BoxLayout
import javax.swing.Box
import javax.swing.JScrollPane
import javax.swing.JComboBox
import javax.swing.JPanel
import javax.swing.JOptionPane
import javax.swing.JMenuBar
import javax.swing.JMenu
import javax.swing.JMenuItem
import javax.swing.JFileChooser
import javax.swing.filechooser.FileNameExtensionFilter
import javax.swing.text.DefaultCaret

module KSP
  module RSS
    class UI < JFrame
      attr_reader :reporter, :progress, :build_button, :checkboxes

      FILTER_DEFAULTS = 0
      FILTER_RECCOMMENDED = 1
      FILTER_ALL = 2

      def initialize(*args)
        super "Mod Bundler"

        @mod_filter = FILTER_DEFAULTS

        build_layout
        load_manifest(args.first)

        setDefaultCloseOperation JFrame::EXIT_ON_CLOSE
        pack
        setVisible true
      end

      def say(message)
        reporter.append(message + "\n")
        reporter.revalidate
      end

      def warn_and_abort(message)
        JOptionPane.showMessageDialog(nil, message)
        throw :terminate, :abort
      end

      def build_layout
        self.setPreferredSize(Dimension.new(600, 400))

        menubar = JMenuBar.new
        menu = JMenu.new("File")

        item = JMenuItem.new("Open Manifest")
        item.addActionListener { |e| choose_manifest }
        menu.add(item)
        item = JMenuItem.new("Exit")
        item.addActionListener { |e| java.lang.System.exit(0) }
        menu.add(item)

        menubar.add(menu)

        self.setJMenuBar(menubar)

        @checkboxes = JPanel.new
        scroller = JScrollPane.new(@checkboxes)
        @reporter = JTextArea.new(1, 40)
        @progress = JProgressBar.new
        reporterScroller = JScrollPane.new(@reporter)
        @build_button = JButton.new("Build it!")
        quit = JButton.new("Exit")
        combo = JComboBox.new(["Show only default mods", "Show only recommended mods", "Show all available mods"].to_java(:string))

        combo.setSelectedIndex(@mod_filter)
        combo.addActionListener { |e| refilter_displayed_mods(combo.getSelectedIndex) }

        @reporter.setEditable(false)
        @reporter.getCaret.setUpdatePolicy(DefaultCaret::ALWAYS_UPDATE)

        height = reporter.getPreferredSize.getHeight
        rect = java.awt.Rectangle.new(0, height, 10, 10)
        reporter.scrollRectToVisible(rect)
        @progress.setStringPainted(true)

        @checkboxes.setLayout(BoxLayout.new(@checkboxes, BoxLayout::PAGE_AXIS))

        contentPane = JPanel.new
        contentPane.setLayout(BoxLayout.new(contentPane, BoxLayout::LINE_AXIS))

        listPane = JPanel.new
        listPane.setLayout(BoxLayout.new(listPane, BoxLayout::PAGE_AXIS))

        infoPane = JPanel.new
        infoPane.setLayout(BoxLayout.new(infoPane, BoxLayout::PAGE_AXIS))

        listPane.add(combo)
        listPane.add(Box.createRigidArea(Dimension.new(0,5)))
        listPane.add(scroller)

        infoPane.add(reporterScroller)
        infoPane.add(@progress)

        contentPane.add(listPane)
        contentPane.add(infoPane)

        buttonPane = JPanel.new
        buttonPane.setLayout(BoxLayout.new(buttonPane, BoxLayout::LINE_AXIS))

        buttonPane.add(@build_button)
        listPane.add(Box.createRigidArea(Dimension.new(5,0)))
        buttonPane.add(quit)

        quit.add_action_listener do |evt|
          java.lang.System.exit(0)
        end

        @build_button.add_action_listener do |evt|
          build_archive
        end

        add(contentPane, BorderLayout::CENTER)
        add(buttonPane, BorderLayout::PAGE_END)
      end

      def finish_build
        @build_button.setEnabled(true)
        @progress.setValue(0)
        @progress.setString "done"
        say "done"
      end

      def resolve_deps_for(name, deps=[])
        requires = (@manifest[name].requires || []) - deps

        requires.each do |r|
          deps << r
          deps.concat resolve_deps_for(r, deps)
        end

        deps
      end

      def build_archive
        @build_button.setEnabled(false)
        @reporter.setText("")
        @progress.setString("")

        list = @manifest.mods.select { |name| @manifest[name].required? || @selected_mods[name] }

        # include requirements
        mod_names = []
        list.each do |l|
          mod_names << l
          mod_names = resolve_deps_for(l, mod_names)
        end

        mod_names = mod_names.sort.uniq
        mods = mod_names.map { |name| @manifest[name] }
        steps = mods.count * 4

        # all are compatible with each other?
        all_good = true
        0.upto(mods.length-2) do |i|
          m1 = mods[i]
          (i+1).upto(mods.length-1) do |j|
            m2 = mods[j]
            if !m1.compatible_with?(m2)
              say "\"#{m1}\" is not compatible with \"#{m2}\""
              all_good = false
            end
          end
        end

        if !all_good
          say "Incompatible mods are selected, so the build cannot succeed"
          finish_build
          return
        end

        @progress.setMinimum(0)
        @progress.setMaximum(steps)

        n = 0

        Thread.new do
          say "cleaning previous build..."
          FileUtils.rm_f(@manifest.archive)
          FileUtils.rm_rf("build")

          begin
            status = catch :terminate do
              mods.each { |m| m.download(self);     @progress.setValue(n+=1) }
              mods.each { |m| m.unpack(self);       @progress.setValue(n+=1) }
              mods.each { |m| m.build(self);        @progress.setValue(n+=1) }
              mods.each { |m| m.install(mod_names); @progress.setValue(n+=1) }
            end

            if status == :abort
              say "build aborted"
              finish_build
              return
            end

            say "building zip file..."
            @progress.setValue(0)
            @progress.setMinimum(0)
            @progress.setMaximum(100)

            zipfile = Java::NetLingalaZip4jCore::ZipFile.new(@manifest.archive)
            parameters = Java::NetLingalaZip4jModel::ZipParameters.new
            constants = Java::NetLingalaZip4jUtil::Zip4jConstants
            progressMonitor = Java::NetLingalaZip4jProgress::ProgressMonitor

            parameters.setCompressionMethod(constants.COMP_DEFLATE)
            parameters.setCompressionLevel(constants.DEFLATE_LEVEL_ULTRA)

            zipfile.setRunInThread(true)
            monitor = zipfile.getProgressMonitor

            Dir[File.join("build", "*")].each do |n|
              zipfile.addFolder(n, parameters)

              while monitor.getState == progressMonitor::STATE_BUSY
                @progress.setValue(monitor.getPercentDone)
                name = (monitor.getFileName || "").sub(/^.*\Wbuild\W/, "")
                @progress.setString(name)
                Thread.pass
              end
            end

            JOptionPane.showMessageDialog(nil,
              "All done!\n\n" +
              "Your lovingly-crafted \"#{@manifest.bundle}\" bundle\n" +
              "has been custom-built just for you. It's all waxed\n" +
              "and fueled and is waiting for you here:\n\n" +
              File.expand_path(@manifest.archive))

          rescue Exception => e
            say "oops: #{e.class} (#{e.message})"
            warn "#{e.class} (#{e.message})"
            e.backtrace.each do |line|
              warn "  #{line}"
            end
          end

          finish_build
        end
      end

      def choose_manifest
        chooser = JFileChooser.new
        filter = FileNameExtensionFilter.new("Manifest Files", "manifest")
        chooser.setFileFilter(filter);
        chooser.addChoosableFileFilter(filter);
        value = chooser.showOpenDialog(self)
        if value == JFileChooser::APPROVE_OPTION
          load_manifest(chooser.getSelectedFile.to_s)
        end
      end

      def refilter_displayed_mods(index)
        @mod_filter = index
        redraw_checkboxes
      end

      def filter_mods(list)
        list.select do |mod_name|
          mod = @manifest[mod_name]

          if !mod.visible? || mod.required?
            # invisible and required mods are never listed
            false
          else
            case @mod_filter
              when FILTER_DEFAULTS
                @manifest.defaults.include?(mod_name)
              when FILTER_RECCOMMENDED
                @manifest.defaults.include?(mod_name) ||
                  @manifest.recommended.include?(mod_name)
              when FILTER_ALL
                true
              else
                raise "Unknown filter value: #{@mod_filter}"
            end
          end
        end
      end

      def load_manifest(which=nil)
        @manifest = Manifest.new(which)

        @selected_mods = { }
        @manifest.defaults.each { |name| @selected_mods[name] = true }

        redraw_checkboxes
      end

      def redraw_checkboxes
        @checkboxes.removeAll

        @manifest.categories.each do |category|
          mods = filter_mods(@manifest.category(category).sort)

          if mods.any?
            label = JLabel.new(category.capitalize)
            font = label.font.java_send(:deriveFont, [Java::int], Font::BOLD)
            label.setFont(font)

            @checkboxes.add(label)
            @checkboxes.add(Box.createRigidArea(Dimension.new(0,5)))

            mods.each do |mod_name|
              mod = @manifest[mod_name]

              cb = JCheckBox.new(mod.to_s, @selected_mods[mod.name])

              cb.add_action_listener do |evt|
                @selected_mods[mod.name] = evt.source.isSelected
              end

              @checkboxes.add(cb)
            end

            @checkboxes.add(Box.createRigidArea(Dimension.new(0,15)))
          end
        end

        @checkboxes.revalidate
      end
    end
  end
end
