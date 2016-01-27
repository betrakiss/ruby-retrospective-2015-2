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
      split  = date_string.split('-')

      @year  = split[0].to_i
      @month = split[1].to_i
      @day   = split[2].to_i

      @date_string = date_string
    end

    def to_s
      @date_string
    end

    def add(period)
      match = period.match(/(\d+)(\w+)/)
      @days += period_to_days(match[0], match[1])
    end

    def after(days)
      days_after_date = to_days + days
      month_day = (days_after_date % 360) % 30
      month = 1 + (days_after_date % 360) / 30
      year = days_after_date / 360

      Date.new(sprintf('%.4d-%.2d-%.2d', year, month, month_day))
    end

    def to_days
      year * 360 + (month - 1) * 30 + day
    end

    def ==(other)
      to_days == other.to_days
    end

    def -(other)
      to_days - other.to_days
    end
  end

  class Note
    attr_reader :header, :file_name, :tags, :period

    def initialize(header, file_name, *tags)
      @file_name = file_name
      @header    = header
      @tags      = tags
      @status    = :topostpone
      @body      = ''
      @sub_notes     = []
    end

    def scheduled(date = nil)
      return @scheduled unless date

      split = date.split(' ')
      @period = split[1] if split.size > 1
      @scheduled = Date.new(split[0])
    end

    def status(status = nil)
      @status = status || @status
    end

    def body(body = nil)
      @body = body || @body
    end

    def note(header, *tags, &block)
      @sub_notes << Note.new(header, @name, *tags)
      @sub_notes.last.instance_eval(&block)
    end

    def flatten_sub_notes
     @sub_notes.flat_map { |sub_note| [sub_note] + sub_note.flatten_sub_notes }
    end

    def scheduled_for?(date)
      return true if @scheduled == date
      return false if (not @period or @scheduled - date > 0)

      target = date.to_days
      current = @scheduled.to_days

      (target - current) % period_to_days(@period[1].to_i, @period[2]) == 0
    end

    def period_to_days(amount, type)
      PERIODS[type] * amount
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
      @notes.last.instance_eval(&block)
    end

    def daily_agenda(target_date)
      agenda = flatten_notes.select { |note| note.scheduled_for?(target_date) }
      agenda.map! { |note| ScheduledNote.new(note, target_date) }

      FilteredNotes.new(agenda)
    end

    def weekly_agenda(target_date)
      agenda = (0..6).flat_map do |day|
        daily_agenda(target_date.after(day)).notes
      end

      FilteredNotes.new(agenda)
    end

    def flatten_notes
      notes + notes.flat_map { |note| note.flatten_sub_notes }
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


    def where(tag: nil, status: nil, text: nil)
      filtered = @notes.dup

      filter_by_tag(filtered, tag) if tag
      filter_by_status(notes, status) if status
      filter_by_text(notes, text) if text

      p filtered
      FilteredNotes.new(filtered)
    end

    def filter_by_tag(notes, tag)
      notes.select! { |n| n.tags.include? tag }
    end

    def filter_by_status(notes, status)
      notes.select! { |n| n.status == status }
    end

    def filter_by_text(notes, text)
      notes.select! { |n| n.header =~ text or n.body =~ text }
    end
  end
end
