
class StructuredError < StandardError
  attr_reader :source

  def initialize(msg, source=nil)
    super(msg)
    @source = source
  end

  def to_h
    hash = {
      'description' => message,
      'types' => self.class.ancestors.map(&:name) - Exception.ancestors.map(&:name),
      'backtrace' => backtrace,
    }

    hash['source'] = source if source

    hash
  end
end
