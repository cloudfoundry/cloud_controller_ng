class HttpRequestError < StructuredError
  attr_reader :uri, :method

  def initialize(msg, uri, method, nested_exception)
    super(msg, nested_exception)

    @uri = uri
    @method = method.to_s.upcase
  end

  def to_h
    hash = super
    hash['http'] = {
      'uri' => uri,
      'method' => method,
    }
    hash
  end
end
