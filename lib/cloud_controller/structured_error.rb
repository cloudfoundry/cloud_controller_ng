
class StructuredError < StandardError
  attr_reader :error

  def initialize(msg, error=nil)
    super(msg)
    @error = error
  end

  def to_h
    hash = {
      'description' => message,
      'types' => self.class.ancestors.map(&:name) - Exception.ancestors.map(&:name),
      'backtrace' => backtrace,
    }

    hash['error'] = error if error

    hash
  end
end
