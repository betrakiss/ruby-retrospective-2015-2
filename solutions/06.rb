module TurtleGraphics
  class Point < Struct.new(:x, :y)
    MOVEMENTS = {
      :right => [0,  1],
      :down  => [1,  0],
      :left  => [0, -1],
      :up    => [-1, 0]
    }.freeze

    def next(direction)
      coordinates = MOVEMENTS[direction]
      Point.new(x + coordinates.first, y + coordinates.last)
    end
  end


  class Turtle
    DIRECTIONS = [:up, :right, :down, :left].freeze

    attr_reader :canvas

    def initialize(rows, columns)
      @rows = rows
      @columns = columns

      @canvas = Array.new(columns) { [0] * rows }
      spawn_at(0, 0)
      look(:right)
    end

    def draw(drawer = Canvas::Matrix.new, &block)
      instance_eval &block

      @canvas[@position.x][@position.y] += 1
      drawer.to_canvas(@canvas)
    end

    def move
      @canvas[@position.x][@position.y] += 1

      next_position = @position.next(@looks_at)
      next_position.x %= @rows
      next_position.y %= @columns

      spawn_at(next_position.x, next_position.y)
    end

    def turn_left
      look(DIRECTIONS[DIRECTIONS.index(@looks_at) - 1])
    end

    def turn_right
      look(DIRECTIONS[(DIRECTIONS.index(@looks_at) + 1) % DIRECTIONS.size])
    end

    def spawn_at(row, column)
      @position = Point.new(row, column)
    end

    def look(orientation)
      @looks_at = orientation
    end
  end

  module Canvas
    class Matrix
      def to_canvas(canvas)
        canvas
      end
    end

    class ASCII
      def initialize(symbols)
        @symbols = symbols
        @step = 1.0 / (symbols.size - 1)
      end

      def to_canvas(canvas)
        max_steps = canvas.map(&:max).max
        asci = ""
        canvas.each do |row|
          row.each { |cell| asci += pick_symbol(cell, max_steps) }
          asci += "\n"
        end

        asci
      end

      def pick_symbol(cell, max)
        intensity = max == 0 ? max : cell.to_f / max
        @symbols[(intensity * (@symbols.size - 1)).ceil]
      end
    end

    class HTML
      HEADER = '<!DOCTYPE html><html><head>' \
               '<title>Turtle graphics</title>%s</head>'

      CSS    = '<style>table {border-spacing: 0;} tr{padding: 0;}' \
               'td {width: %spx;height: %spx;background-color: black;' \
               'padding: 0;}</style>'

      ENTRY  = '<td style="opacity: %s"></td>'


      def initialize(td_size)
        @document = HEADER % (CSS % [td_size, td_size])
        @document += '<body><table>'
      end

      def to_canvas(canvas)
        max_steps = canvas.map(&:max).max

        canvas.each do |row|
          @document += '<tr>'

          row.each do |cell|
            opacity = calculate_opacity(cell, max_steps)
            @document += ENTRY % format('%.2f', opacity)
          end
          @document += '</tr>'
        end

        @document += '</table></body></html>'
      end

      def calculate_opacity(cell, max)
        max == 0 ? max : cell.to_f / max
      end
    end
  end
end
