# encoding: utf-8
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib')) 
require "prawn"        
require "benchmark"

Prawn::Document.generate("the_prince.pdf", :compress => true) do
  # Open-source font courtesy of: http://www.theleagueofmoveabletype.com/
  font_families.update(
    "GoudyBookletter1911" => {
      :normal => "#{Prawn::BASEDIR}/data/fonts/GoudyBookletter1911.ttf"
    })
  font "GoudyBookletter1911"

  # Draws a section heading, centered in 80% of the current column's width.
  #
  def heading(heading_text)
    move_down 6 unless (y - bounds.absolute_top).abs < 1

    height = height_of(heading_text, :width => 0.8 * bounds.width)
    reflow_bounds = bounds.stretchy? ? margin_box : bounds
    bounds.move_past_bottom if (y - reflow_bounds.absolute_bottom) < height

    bounding_box([bounds.left_side - margin_box.left_side + 
                    (0.1 * bounds.width), cursor],
                  :width => 0.8 * bounds.width) do
      text heading_text, :align => :center
    end
    move_down 6
  end

  # Draws a justified paragraph the width of the current column, using
  # Knuth-Plass hyphenation from Crawdad.
  #
  def paragraph(paragraph_text)
    text(paragraph_text, :text_box_class => Prawn::Text::KnuthPlassBox,
         :tokenizer_options => { :hyphenation => true })
    move_down 6
  end

  # Title page
  move_down 240
  text "The Prince", :size => 72, :align => :center
  text "Niccolò Machiavelli", :size => 36, :align => :center
  move_down 36
  text "translated by Ninian Hill Thomson", :size => 16, :align => :center

  start_new_page

  column_box([0, cursor], :columns => 2, :width => bounds.width) do
    File.open("#{Prawn::BASEDIR}/data/the_prince.txt") do |f|

      until f.eof?
        case (line = f.gets.strip)
        when /^\s*$/         # no-op
        when /^= (.*)$/ then heading($1)
        else                 paragraph(line)
        end
      end

    end
  end

  repeat(:all, :dynamic => true) do
    if page_number > 1
      canvas do
        text_box "—#{page_number}—", :at => [0, 28], :align => :center
      end
    end
  end

end

