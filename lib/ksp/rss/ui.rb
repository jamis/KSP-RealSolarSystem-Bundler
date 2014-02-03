require 'fileutils'
require 'ksp/rss/modlist'
require 'ksp/rss/settings'
require './jars/zip4j_1.3.2.jar'

include Java

import java.awt.Dimension
import java.awt.Rectangle
import java.awt.Color
import java.awt.BorderLayout
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
import javax.swing.JPanel
import javax.swing.JOptionPane

module KSP
  module RSS
    class UI < JFrame
      attr_reader :reporter, :progress, :build_button

      def initialize
        super "Real Solar System"
        @mod_list = ModList.load_list

        @selected_mods = { }
        Settings::DEFAULTS.each { |opt| @selected_mods[opt] = true }

        build_layout

        setDefaultCloseOperation JFrame::EXIT_ON_CLOSE
        pack
        setVisible true
      end

      def say(message)
        reporter.append(message + "\n")
        reporter.revalidate

        height = reporter.getPreferredSize.getHeight
        rect = Rectangle.new(0, height, 10, 10)
        reporter.scrollRectToVisible(rect)
      end

      def warn_and_abort(message)
        JOptionPane.showMessageDialog(nil, message)
        throw :terminate, :abort
      end

      def build_layout
        self.setPreferredSize(Dimension.new(600, 400))

        title = JLabel.new("Available Mods")
        checkboxes = JPanel.new
        scroller = JScrollPane.new(checkboxes)
        @reporter = JTextArea.new(25, 40)
        @progress = JProgressBar.new
        reporterScroller = JScrollPane.new(@reporter)
        @build_button = JButton.new("Build it!")
        quit = JButton.new("Exit")

        @reporter.setEditable(false)
        @progress.setStringPainted(true)

        checkboxes.setLayout(BoxLayout.new(checkboxes, BoxLayout::PAGE_AXIS))

        @mod_list.each do |mod|
          if mod.optional? && !mod.disabled?
            cb = JCheckBox.new(mod.to_s, @selected_mods[mod.option])

            cb.add_action_listener do |evt|
              @selected_mods[mod.option] = evt.source.isSelected
            end

            checkboxes.add cb
          end
        end

        contentPane = JPanel.new
        contentPane.setLayout(BoxLayout.new(contentPane, BoxLayout::LINE_AXIS))

        listPane = JPanel.new
        listPane.setLayout(BoxLayout.new(listPane, BoxLayout::PAGE_AXIS))

        infoPane = JPanel.new
        infoPane.setLayout(BoxLayout.new(infoPane, BoxLayout::PAGE_AXIS))

        listPane.add(title)
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

      def build_archive
        @build_button.setEnabled(false)
        @reporter.setText("")

        mods = @mod_list.select { |m| !m.optional? || @selected_mods[m.option] }
        steps = mods.count * 4

        @progress.setMinimum(0)
        @progress.setMaximum(steps)

        n = 0

        Thread.new do
          FileUtils.rm_f("HardMode.zip")
          FileUtils.rm_rf("build")

          begin
            status = catch :terminate do
              mods.each { |m| m.download(self);   @progress.setValue(n+=1) }
              mods.each { |m| m.unpack(self);     @progress.setValue(n+=1) }
              mods.each { |m| m.build(self);      @progress.setValue(n+=1) }
              mods.each { |m| m.post_build(self); @progress.setValue(n+=1) }
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

            zipfile = Java::NetLingalaZip4jCore::ZipFile.new("HardMode.zip")
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
                name = monitor.getFileName.sub(/^.*#{File::SEPARATOR}build#{File::SEPARATOR}/, "")
                @progress.setString(name)
                Thread.pass
              end
            end

            say "done with busy..."
            while monitor.getResult == progressMonitor::RESULT_WORKING
              #@progress.setValue(monitor.getPercentDone)
              #@progress.setString(File.basename(monitor.getFileName))
              Thread.pass
            end

            JOptionPane.showMessageDialog(nil,
              "All done!\n\n" +
              "Your lovingly-crafted \"real solar system\" bundle\n" +
              "has been custom-built just for you. It's all waxed\n" +
              "and fueled and is waiting for you here:\n\n" +
              File.expand_path("HardMode.zip"))

          rescue Exception => e
            say "oops: #{e.class} (#{e.message})"
          end

          finish_build
        end
      end
    end
  end
end
