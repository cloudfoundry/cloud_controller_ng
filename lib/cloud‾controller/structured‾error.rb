class StructuredError < StandardError
  attr_reader :source
  attr_accessor :error_prefix

  def initialize(msg, source)
    super(msg)
    @source = source
  end

  def message
    "#{error_prefix}#{super}"
  end

  def to_h
    {
      'description' => message,
      'backtrace' => backtrace,
      'source' => hashify(source),
    }
  end

  private

  def hashify(source)
    if source.respond_to?(:to_h)
      source.to_h
    elsif source.respond_to?(:to_hash)
      source.to_hash
    elsif source.is_a?(Exception)
      {
        'description' => source.message,
        'backtrace' => source.backtrace,
      }
    else
      source.to_s
    end
  rescue TypeError
    source.to_s
  end
end
