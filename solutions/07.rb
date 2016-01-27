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

      splitted = date_string.split('-')

      @year = '0' * (YEAR_COUNT - splitted[0].size) + splitted[0]
      @month = '0' * (MONTH_COUNT - splitted[1].size) + splitted[1]
      @day = '0' * (DAY_COUNT - splitted[2].size) + splitted[2]
    end

    def to_s
      "%s-%s-%s" % [@year, @month, @day]
    end
  end

  class Note < File
    attr_reader :header
    attr_reader :file_name
    attr_reader :tags

    def initialize(header, file_name, *tags)
      @header = header
      @file_name = file_name
      @tags = tags
      @status = :topostpone
      @body = ''
    end

    def scheduled(date=nil)
      return @scheduled unless date
      @scheduled = Date.new(date)
    end

    def status(status=nil)
      return @status unless status
      @status = status
    end

    def body(body=nil)
      return @body unless body
      @body = body
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

  end
end

file = LazyMode.create_file('work') do
  note 'sleep', :important, :wip do
    scheduled '2012-08-07'
    status :postponed
    body 'Try sleeping more at work'
  end


  note 'useless activity' do
    scheduled '2012-08-07'
  end
end
