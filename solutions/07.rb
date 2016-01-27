module LazyMode

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

      @year = '0' * (YEAR_COUNT - split[0].size) + split[0]
      @month = '0' * (MONTH_COUNT - split[1].size) + split[1]
      @day = '0' * (DAY_COUNT - split[2].size) + split[2]
    end

    def to_s
      "%s-%s-%s" % [@year, @month, @day]
    end

    def add(period)
      match = period.match(/(\d+)(\w+)/)
      puts match
      @days += period_to_days(match[0], match[1])
    end

    def period_to_days(amount, type)
      case type
        when 'w' then amount * 7
        when 'd' then amount
        when 'm' then amount * 30
      end
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

    # def daily_agenda(target_date)
    #   agenda = []
    #   agenda_iteration(@notes, agenda, target_date)

    #   return Class.new do
    #     def note
    #       agenda
    #     end
    #   end
    # end

    # def agenda_iteration(notes, agenda, target_date)
    #   notes.each do |note|
    #     agenda << note if note.scheduled == target_date

    #     loop
    #       periodic = note.scheduled.add(note.period) if note.period
    #       break unless periodic
    #       break if periodic > target_date
    #       if periodic == target_date
    #         agenda << note
    #       end
    #     end

    #     agenda_iteration(note.notes, agenda, target_date)
    #   end
    # end

  end
end
