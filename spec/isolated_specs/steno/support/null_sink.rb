class NullSink
  attr_accessor :records

  def initialize
    @records = []
  end

  def add_record(record)
    @records << record

    nil
  end

  def flush
    nil
  end
end
