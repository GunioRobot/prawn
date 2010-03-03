require 'crawdad'

module Prawn
  module Text
    class KnuthPlassBox < Box

      # token helper functions
      include Crawdad::Tokens

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
              token_type(remaining_tokens.first) == :box

            return remaining_tokens
          end

          # skip over glue and penalties at the beginning of each line
          tokens.shift until tokens.empty? || token_type(tokens.first) == :box

          x = @at[0]
          y = @at[1] + @baseline_y

          tokens.each_with_index do |token, i|
            case token_type(token)
            when :box
              puts "Drawing #{box_content(token)}"
              @document.draw_text!(box_content(token), :at => [x, y])
              x += token_width(token)
            when :glue
              r = breakpoint.ratio
              w = case
                   when r > 0
                     token_width(token) + (r * glue_stretch(token))
                   when r < 0
                     token_width(token) + (r * glue_shrink(token))
                   else token_width(token)
                   end
              x += w
            when :penalty
              # Draw a hyphen when we have broken at a nonzero-width flagged
              # penalty.
              #
              # XXX: We could make penalties carry their own content, too, to
              # be super-fancy (support different types of hyphens, etc.).
              if (i == tokens.length - 1) && penalty_flagged?(token) && 
                  token_width(token) > 0
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
