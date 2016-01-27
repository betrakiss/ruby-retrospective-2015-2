module TurtleGraphics
  class Point
    DIRECTIONS = {
      :up    => [-1, 0],
      :right => [0, 1],
      :down  => [1, 0],
      :left  => [0, -1]
    }

    attr_accessor :x
    attr_accessor :y

    def initialize(x, y)
      @x = x
      @y = y
    end

    def next(direction)
      coordinates = DIRECTIONS[direction]
      Point.new(@x + coordinates.first, @y + coordinates.last)
    end
  end


  class Turtle
    DIRECTIONS = [:up, :right, :down, :left]

    attr_reader :canvas

    def initialize(rows, columns)
      @rows = rows
      @columns = columns
      @spawned = false

      init_canvas
      look(:right)
    end

    def init_canvas
      @canvas = []
      @rows.times { @canvas << Array.new(@columns, 0) }
    end

    def draw(drawer = nil, &block)
      instance_eval &block

      return @canvas unless drawer
      drawer.to_canvas(@canvas)
    end

    def move
      spawn_at(0, 0) unless @spawned

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
      @spawned = true
      @position = Point.new(row, column)
      @canvas[row][column] += 1
    end

    def look(orientation)
      unless (DIRECTIONS.include? orientation)
        raise ArgumentError, "'#{orientation}' is not a valid direction."
      end

      @looks_at = orientation
    end
  end

  module Canvas
    class ASCII
      def initialize(symbols)
        @symbols = symbols
        @step = 1.0 / (symbols.size - 1)
      end

      def to_canvas(canvas)
        asci = ""
        canvas.each do |row|
          row.each { |cell| asci += pick_symbol(cell, row.max) }
          asci += "\n"
        end

        asci
      end

      def pick_symbol(cell, max)
        intensity = max == 0 ? max : cell.to_f / max
        @symbols[(intensity / @step).floor]
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
      end

      def to_canvas(canvas)
        @document += '<body><table>'

        canvas.each do |row|
          @document += '<tr>'

          row.each do |cell|
            opacity = calculate_opacity(cell, row.max)
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
