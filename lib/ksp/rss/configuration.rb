require 'strscan'

module KSP
  module RSS
    class Configuration
      class ParseError < RuntimeError; end

      def self.load_file(filename)
        self.new(File.read(filename, mode: "rt"))
      end

      attr_reader :contents

      def initialize(text)
        @contents = parse_text(text)
      end

      # +target_path+ is a string like "MODULE" or "* MODULE" or
      #   "PART MODULE RESOURCE"
      def remove(target_path, attributes={})
        remove_from_block([], @contents, target_path.split, attributes)
        self
      end

      # +parent_path+ is the path to the node where the chunk ought to
      # be added, e.g. "Part", or "* module".
      def add(parent_path, conditions, chunk)
        parsed = parse_text(chunk)
        target = find_block([], @contents, parent_path.split, conditions)

        if !target
          warn "no parent found at #{parent_path.inspect}"
        else
          parsed.each do |key, list|
            target[key] ||= []
            target[key].concat(list)
          end
        end

        self
      end

      # note that this will overwrite any existing values at the given keys!
      # to add a duplicate key with a different value, use #add instead.
      def set(parent_path, conditions, chunk)
        parsed = parse_text(chunk)
        target = find_block([], @contents, parent_path.split, conditions)

        if !target
          warn "no parent found at #{parent_path.inspect}"
        else
          target.update(parsed)
        end

        self
      end

      def to_s
        string = ""

        @contents.each do |label, list|
          list.each { |value| string << value_to_string(label, value) }
        end

        string
      end

      private

      def remove_from_block(current_path, block, target_path, attributes)
        block.delete_if do |label, list|
          new_path = current_path + [label]
          list.delete_if do |value|
            if value_matches?(new_path, target_path, value, attributes)
              true
            elsif value.is_a?(Hash)
              remove_from_block(new_path, value, target_path, attributes)
              false
            end
          end

          list.empty?
        end
      end

      def find_block(current_path, block, target_path, attributes)
        return block if value_matches?(current_path, target_path, block, attributes)

        block.each do |label, list|
          new_path = current_path + [label]
          list.each do |value|
            if value.is_a?(Hash)
              result = find_block(new_path, value, target_path, attributes)
              return result if result
            end
          end
        end

        nil
      end

      def value_matches?(current_path, target_path, value, attributes)
        return false unless path_match?(current_path, target_path)

        if value.is_a?(Hash)
          attributes.all? { |k,v| value[k].include?(v) }
        else
          value == attributes
        end
      end

      def path_match?(path1, path2)
        n = -1

        loop do
          break if path1[n] == "*" || path2[n] == "*" ||
            (path1[n] == nil && path2[n] == nil)

          return false unless path1[n] && path2[n] && path1[n].downcase == path2[n].downcase

          n -= 1
        end

        true
      end

      def value_to_string(label, value, indent_level=0)
        string = ""

        string << ("  " * indent_level) << label

        if value.is_a?(Hash)
          string << block_to_string(value, indent_level) << "\n"
        else
          string << " = " << value << "\n"
        end

        string
      end

      def block_to_string(block, indent_level)
        string = ""

        if block.empty?
          string << " {}"
        else
          string << "\n" << ("  " * indent_level) << "{\n"

          block.each do |key, list|
            list.each do |value|
              string << value_to_string(key, value, indent_level+1)
            end
          end

          string << ("  " * indent_level) << "}"
        end

        string
      end

      def parse_text(text)
        scanner = StringScanner.new(text)
        parse_block_body(scanner)
      end

      def skip_white(scanner)
        loop do
          break unless scanner.skip(/\s*/)
          break unless scanner.skip(/\/\/.*$/)
        end
      end

      def eat(scanner, pattern)
        match = scanner.scan(pattern)
        raise ParseError, "expected #{pattern.inspect} at #{scanner.peek(10).inspect}" unless match
        return match
      end

      def parse_label(scanner)
        skip_white(scanner)
        label = eat(scanner, /[^\s=]+/)
        skip_white(scanner)

        return label
      end

      def parse_block(scanner)
        skip_white(scanner)

        eat(scanner, /{/)
        block = parse_block_body(scanner)
        scanner.scan(/}/) # should #eat this, but it might be missing

        block
      end

      def parse_block_body(scanner)
        block = {}

        loop do
          begin
            skip_white(scanner)

            # eos here is technically an error, but there are mods with
            # such configs, and we ought to handle them like KSP does
            break if scanner.check(/}/) || scanner.eos?

            key = eat(scanner, /[^\s=]+/)
            if scanner.scan(/\s*=\s*/)
              value = eat(scanner, /[^}\r\n]+/)
            else
              value = parse_block(scanner)
            end

            block[key] ||= []
            block[key] << value
          rescue ParseError => e
            warn "parse error -- skipping value (#{e.message})"
          end
        end

        block
      end
    end
  end
end
