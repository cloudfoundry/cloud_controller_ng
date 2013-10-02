class StructuredError < StandardError
  attr_reader :source

  def initialize(msg, source)
    super(msg)
    @source = source
  end

  def to_h
    {
      'description' => message,
      'types' => Hashify.types(self),
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
      Hashify.exception(source)
    else
      source.to_s
    end
  end
end
