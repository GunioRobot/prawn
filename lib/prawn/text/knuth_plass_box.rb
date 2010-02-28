require 'crawdad'

module Prawn
  module Text
    class KnuthPlassBox < Box

      def initialize(text, options={})
        super
        @tokenizer = Crawdad::PrawnTokenizer.new(@document)
        @tokenizer_options = options[:tokenizer_options]
      end

      def _render(text) # :nodoc:
        @text = text
        para = if text.is_a?(String)
                 # TODO: tokenizer options
                 stream = @tokenizer.paragraph(text, @tokenizer_options)
                 # TODO: line_widths
                 Crawdad::Paragraph.new(stream, :width => @width)
               else
                 # We are rendering a continuation paragraph, and +text+ is a
                 # token stream previously returned by _render.
                 Crawdad::Paragraph.new(text, :width => @width)
               end

        @line_height = @document.font.height
        @descender   = @document.font.descender
        @ascender    = @document.font.ascender
        @baseline_y  = -@ascender

        # TODO: tolerance.
        lines = para.lines
        
        lines.each_with_index do |(tokens, breakpoint), i|
          if @baseline_y.abs + @descender > @height
            remaining_tokens = lines[i..-1].inject([]) { |ts, (line, _)| 
              ts.concat(line); ts }
            remaining_tokens.shift until remaining_tokens.empty? || 
              Crawdad::Box === remaining_tokens.first

            return remaining_tokens
          end

          # skip over glue and penalties at the beginning of each line
          tokens.shift until tokens.empty? || Crawdad::Box === tokens.first

          x = @at[0]
          y = @at[1] + @baseline_y

          tokens.each_with_index do |token, i|
            case token
            when Crawdad::Box
              @document.draw_text!(token.content, :at => [x, y])
              x += token.width
            when Crawdad::Glue
              r = breakpoint.ratio
              w = case
                   when r > 0
                     token.width + (r * token.stretch)
                   when r < 0
                     token.width + (r * token.shrink)
                   else token.width
                   end
              x += w
            when Crawdad::Penalty
              # Draw a hyphen when we have broken at a nonzero-width flagged
              # penalty.
              #
              # XXX: We could make penalties carry their own content, too, to
              # be super-fancy (support different types of hyphens, etc.).
              if (i == tokens.length - 1) && token.flagged? && token.width > 0
                @document.draw_text!('-', :at => [x, y])
              end
            end
          end

          # TODO: :ellipses
          # print_ellipses = (@overflow == :ellipses && last_line? &&
          #                   remaining_text.length > 0)
          
          @baseline_y -= (@line_height + @leading)
          # TODO: @single_line
        end

        # If we fell off the end of the loop, there is nothing left to display.
        []
      end

    end
  end
end
