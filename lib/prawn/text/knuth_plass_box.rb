require 'crawdad'

module Prawn
  module Text
    class KnuthPlassBox < Box

      def initialize(text, options={})
        super
        @tokenizer = Crawdad::PrawnTokenizer.new(@document)
      end

      def _render(text) # :nodoc:
        @text = text
        para = if text.is_a?(String)
                 # TODO: tokenizer options
                 stream = @tokenizer.paragraph(text)
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
        lines = para.lines(tolerance=10)
        
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

          tokens.each do |token|
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
              # TODO: add a hyphen when we break at a flagged penalty
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
