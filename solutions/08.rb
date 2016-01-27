class Spreadsheet
  class Error < StandardError
  end

  def initialize(sheet = '')
    @utilities = SheetUtilities.new
    @cells = @utilities.parse_sheet(sheet)
  end

  def empty?
    @cells.empty?
  end

  def cell_at(cell_index)
    @utilities.get_by_cell_index(cell_index).to_s
  end

  def [](cell_index)
    @utilities.calculate_expression(cell_at(cell_index))
  end

  def to_s
    @cells.map do |row|
      row.map { |cell| @utilities.calculate_expression(cell) }.join("\t")
    end.join("\n")
  end
end

class SheetUtilities
  def parse_sheet(sheet)
    @cells = sheet.strip.split(/\n/)
    @cells.map! { |row| row.strip.split(/\t+| {2,}/).map(&:strip) }
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
    arguments.split(',').map do |argument|
      if argument =~ /[A-Z]+[0-9]+/
        argument = get_by_cell_index(argument)
      end

      calculate_expression(argument).strip.to_f
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

    col, row = parse_col($1), $2.to_i - 1

    verify(row, col, cell_index)
  end

  def verify(row, col, cell_index)
    begin
      @cells[row][col]
    rescue NoMethodError
      raise Spreadsheet::Error, "Cell '#{cell_index.strip}' does not exist."
    end
  end

  def calculate_expression(expression)
    return expression if expression[0] != '='

    calculation = parse_formula(expression)
    unless calculation
      raise Spreadsheet::Error, "Invalid expression '#{expression[1..-1]}'"
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
    expected = @formula.arity < 0 ? @formula.arity.abs - 1 : @formula.arity

    if args.count < expected and @formula.arity < 0
      raise Spreadsheet::Error, LESS % [@name, expected, args.count]
    end


    if args.count > expected and @formula.arity > 0 or
        args.count < expected
      raise Spreadsheet::Error, MORE % [@name, expected, args.count]
    end
  end
end

