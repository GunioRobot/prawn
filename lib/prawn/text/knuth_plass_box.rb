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
        # TODO: tokenizer options
        stream = @tokenizer.paragraph(text)
        # TODO: line_widths
        para = Crawdad::Paragraph.new(stream, :width => @width)

        @line_height = @document.font.height
        @descender   = @document.font.descender
        @ascender    = @document.font.ascender
        @baseline_y  = -@ascender

        # TODO: tolerance.
        lines = para.lines(10)
        
        lines.each do |tokens, breakpoint|
          # skip over glue and penalties at the beginning of each line
          tokens.shift until tokens.empty? || Crawdad::Box === tokens.first

          x = @at[0]
          y = @at[1] + @baseline_y

          # TODO: honor @height
          # @baseline_y.abs + @descender <= @height

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

        # TODO: this will not be so simple once we honor @height
        "" # no remaining text
      end

    end
  end
end
