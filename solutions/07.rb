module LazyMode
  PERIODS = {
    'w' => 7,
    'd' => 1,
    'm' => 30
  }


  def self.create_file(name, &block)
    file = File.new(name)
    file.instance_eval &block
    file
  end

  class Date
    YEAR_COUNT = 4
    MONTH_COUNT = 2
    DAY_COUNT = 2

    attr_reader :year
    attr_reader :month
    attr_reader :day

    def initialize(date_string)
      unless date_string =~ /^\d+-\d+-\d+$/
        raise ArgumentError, 'invalid date format'
      end

      split = date_string.split('-')

      @year = split[0].to_i
      @month = split[1].to_i
      @day = split[2].to_i
    end

    def to_s
      year = '0' * (YEAR_COUNT - @year.to_s.size) + @year.to_s
      month = '0' * (MONTH_COUNT - @month.to_s.size) + @month.to_s
      day = '0' * (DAY_COUNT - @day.to_s.size) + @day.to_s

      "%s-%s-%s" % [year, month, day]
    end

    def add(period)
      match = period.match(/(\d+)(\w+)/)
      puts match
      @days += period_to_days(match[0], match[1])
    end

    def period_to_days(amount, type)
      PERIODS[type] * amount
    end

    def ==(other)
      year == other.year and month == other.month and day == other.day
    end
  end

  class Note
    attr_reader :header
    attr_reader :file_name
    attr_reader :tags
    attr_reader :period

    def initialize(header, file_name, *tags)
      @header = header
      @file_name = file_name
      @tags = tags
      @status = :topostpone
      @body = ''
      @notes = []
    end

    def scheduled(date = nil)
      return @scheduled unless date

      split = date.split(' ')
      @period = split[1] if split.size > 1
      @scheduled = Date.new(split[0])
    end

    def status(status = nil)
      return @status unless status
      @status = status
    end

    def body(body = nil)
      return @body unless body
      @body = body
    end

    def note(header, *tags, &block)
      @notes << Note.new(header, @name, *tags)
      @notes.last.instance_eval &block
    end
  end

  class File
    attr_reader :name
    attr_reader :notes

    def initialize(name)
      @name = name
      @notes = []
    end

    def note(header, *tags, &block)
      @notes << Note.new(header, @name, *tags)
      @notes.last.instance_eval &block
    end

    def daily_agenda(target_date)
      agenda = @notes.select { |note| note.scheduled == target_date }
      agenda.map! { |note| ScheduledNote.new(note, target_date) }

      FilteredNotes.new(agenda)
    end
  end

  class ScheduledNote
    attr_reader :date, :file_name, :header, :tags, :status, :body

    def initialize(note, date)
      @file_name = note.file_name
      @header    = note.header
      @tags      = note.tags
      @status    = note.status
      @body      = note.body
      @date      = date
    end
  end

  class FilteredNotes
    attr_reader :notes

    def initialize(notes)
      @notes = notes
    end
  end
end
