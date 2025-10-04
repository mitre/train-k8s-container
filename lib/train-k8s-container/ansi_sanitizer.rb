# frozen_string_literal: true

module TrainPlugins
  module K8sContainer
    # ANSI sequence sanitization module
    # Removes ANSI escape sequences and normalizes line endings
    # Addresses CVE-2021-25743 (terminal escape sequence injection)
    module AnsiSanitizer
      # Pre-compiled regexes for performance (frozen constants)
      CSI_REGEX = /\e\[([;\d]+)?[A-Za-z]/
      OSC_REGEX = /\e\][^\a]*\a/
      CURSOR_REGEX = /\e\[A|\e\[C|\e\[K/
      LINE_ENDING_REGEX = /\r\n?/

      # Remove ANSI escape sequences and normalize line endings
      # @param text [String] The text to sanitize
      # @return [String] Sanitized text with ANSI sequences removed
      def self.sanitize(text)
        return '' if text.nil? || text.empty?

        # Use single string mutation instead of chaining to reduce allocations
        result = text.dup
        result.gsub!(CSI_REGEX, '') # CSI sequences (colors, cursor movement)
        result.gsub!(OSC_REGEX, '') # OSC sequences (terminal title, etc)
        result.gsub!(CURSOR_REGEX, '') # Cursor movement (up, forward, erase)
        result.gsub!(LINE_ENDING_REGEX, "\n") # Normalize all line endings
        result
      end
    end
  end
end
