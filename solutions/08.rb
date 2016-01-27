class Spreadsheet
  class Error < StandardError
  end

  def initialize(sheet = '')
    @cells = []
    @utilities = SheetUtilities.new(@cells)
    @utilities.parse_sheet(sheet)
  end

  def empty?
    @cells.empty?
  end

  def cell_at(cell_index)
    cell = @utilities.get_by_cell_index(cell_index)

    raise Error, "Cell '#{cell_index}' does not exist." unless cell
    cell.to_s
  end

  def [](cell_index)
    @utilities.calculate_expression(cell_at(cell_index))
  end

  def to_s
    tab = ""
    @cells.each do |row|
      row.each { |cell| tab << "#{@utilities.calculate_expression(cell)}\t" }

      tab.chop!
      tab << "\n"
    end
    empty? ? tab : tab.chop
  end
end

class SheetUtilities
  def initialize(cells)
    @cells = cells
  end

  def parse_sheet(sheet)
    sheet.strip.split("\n").each do |row|
      next if row.empty?
      delimiter = /#{Regexp.escape(row.include?("\t") ? "\t" : "  ")}+/

      current = []
      row.strip.split(delimiter).each { |cell| current << cell.strip }
      @cells << current
    end
  end

  def parse_col(col)
    index = 0

    if col.size > 1
      col[0..col.size - 2].each_char do |c|
        index += (c.ord - ('A'.ord - 1)) * ('Z'.ord - 'A'.ord + 1)
      end
    end

    index += col[col.size - 1].ord - ('A'.ord - 1)
    index.to_i - 1
  end

  def extract_args(arguments)
    return unless arguments
    arguments.split(',').map do |argument|
      if argument =~ /[A-Z]+[0-9]+/
        argument = get_by_cell_index(argument)
      end
      argument = argument.strip.to_f
    end
  end

  def parse_formula(expression)
    return $1 if expression.match(/^\=([-+]?\d+\.?\d*)+$/)
    if expression.match(/^\=(\w+\d+)$/)
      return calculate_expression(get_by_cell_index($1))
    end

    if expression.match(/(\w+)\((.*)\)/)
      return Formula.new($1).calculate(*extract_args($2))
    end
    false
  end

  def get_by_cell_index(cell_index)
    cell_index.scan(/([A-Z]+)([0-9]+)/)
    raise Spreadsheet::Error, "Invalid cell index '#{cell_index}'." unless $1

    col = parse_col($1)
    row = $2.to_i - 1

    @cells[row][col] rescue nil
  end

  def calculate_expression(expression)
    return expression if expression[0] != '='

    calculation = parse_formula(expression)
    unless calculation
      raise Spreadsheet::Error, "Invalid expression '#{expression}'"
    end
    calculation.to_s
  end
end

class Formula
  FORMULAS = {
    'ADD'        => ->(a, b, *rest) { [a, b, rest].flatten.reduce(:+) },
    'MULTIPLY'   => ->(a, b, *rest) { [a, b, rest].flatten.reduce(:*) },
    'SUBTRACT'   => ->(x, y) { x - y },
    'DIVIDE'     => ->(x, y) { x / y },
    'MOD'        => ->(x, y) { x % y },
  }

  LESS = "Wrong number of arguments for '%s': expected at least %s, got %s"
  MORE = "Wrong number of arguments for '%s': expected %s, got %s"
  UNKNOWN = "Unknown function '%s'"

  def initialize(name)
    @name = name
    @formula = FORMULAS[name]
    raise Spreadsheet::Error, UNKNOWN % name unless @formula
  end

  def calculate(*args)
    check_arguments(args)
    calculation = @formula.(*args).to_f
    (calculation % 1 == 0.0) ? calculation.to_i : format('%.2f', calculation)
  end

  def check_arguments(args)
    args_count = @formula.arity < 0 ? @formula.arity.abs - 1 : @formula.arity

    if args.count < args_count and @formula.arity < 0
      raise Spreadsheet::Error, LESS % [@name, args_count, args.count]
    end

    if args.count > args_count and @formula.arity > 0 or
        args.count < args_count
      raise Spreadsheet::Error, MORE % [@name, args_count, args.count]
    end
  end
end
