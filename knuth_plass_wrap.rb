require 'prawn'

gem 'crawdad', '0.1.0'
require 'crawdad'

module KnuthPlassWrap
  include Crawdad::Tokens

  def initialize(text, options)
    super
    @tokenizer = Crawdad::PrawnTokenizer.new(@document)
    @wrap_options = options[:wrap_options] || {}
    @wrap_options[:align] = @align
  end
  
  def wrap(text)
    @text = text
    threshold = @wrap_options.delete(:threshold) || case @align
    # TODO: center alignment needs a much higher threshold when dealing with
    # things like headings than with paragraphs
                                                    when :center then 25
                                                    else 5
                                                    end

    para = if text.is_a?(String)
             stream = @tokenizer.paragraph(text, @wrap_options)
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

    lines = para.lines(threshold)

    lines.each_with_index do |(tokens, breakpoint), i|
      if @baseline_y.abs + @descender > @height
        remaining_tokens = lines[i..-1].inject([]) { |ts, (line, _)| 
          ts.concat(line); ts }
        remaining_tokens.shift until remaining_tokens.empty? || 
          token_type(remaining_tokens.first) == :box

        return remaining_tokens
      end

      # Skip over glue and penalties at the beginning of each line.
      tokens.shift until tokens.empty? || token_type(tokens.first) == :box

      # Suck out the finishing glue for ragged alignment -- otherwise the glue
      # would still be taken into account in the line_width calculation below
      # and force the line left (for ragged-left alignment) or push any hyphens
      # right (for ragged-right).
      if [:left, :right].include? @align
        while tokens[-2] && token_type(tokens[-2]) == :glue
          tokens.delete_at(-2)
        end
      end

      # Calculate the accrued line width so we can position centered or
      # right-aligned (ragged-left) text.
      line_width = tokens.inject(0.0) do |sum, token|
        sum + case token_type(token)
              when :box then token_width(token)
              when :glue then glue_width(breakpoint, token)
              else 0
              end
      end

      # Make sure to account for the final penalty, if we are hyphenating.
      if token_type(tokens[-1]) == :penalty && penalty_flagged?(tokens[-1])
        line_width += token_width(tokens[-1])
      end

      # Would be easier to delegate to draw_line here, but that doesn't account
      # for the different token types and spacings we can have -- it assumes
      # line spacing is uniform.
      case(@align)
      when :left, :justify
        x = @at[0]
      when :center
        x = @at[0] + @width * 0.5 - line_width * 0.5
      when :right
        x = @at[0] + @width - line_width
      end
      y = @at[1] + @baseline_y

      tokens.each_with_index do |token, i|
        case token_type(token)
        when :box
          @document.draw_text!(box_content(token), :at => [x, y]) if @inked
          x += token_width(token)
        when :glue
          x += glue_width(breakpoint, token)
        when :penalty
          # Draw a hyphen when we have broken at a nonzero-width flagged
          # penalty.
          if (i == tokens.length - 1) && penalty_flagged?(token) && 
              (token_width(token) > 0) && @inked
            @document.draw_text!('-', :at => [x, y])
          end
        end
      end

      @baseline_y -= (@line_height + @leading)
    end

    # If we fell off the end of the loop, there is nothing left to display.
    []
  end

  # Returns the width of the given glue +token+, depending on the ratio of the
  # current +breakpoint+.
  #
  def glue_width(breakpoint, token)
    r = breakpoint.ratio
    case
    when r > 0
      token_width(token) + (r * glue_stretch(token))
    when r < 0
      token_width(token) + (r * glue_shrink(token))
    else token_width(token)
    end
  end

end

Prawn::Text::Box.send :include, KnuthPlassWrap

