class HttpResponseError < StructuredError
  attr_reader :uri, :method, :status

  def initialize(message, uri, method, response)
    @uri = uri
    @method = method.to_s.upcase
    @status = response.code.to_i

    begin
      source = Yajl::Parser.parse(response.body)
    rescue Yajl::ParseError
      source = response.body
    end

    super(message, source)
  end

  def to_h
    hash = super
    hash['http'] = {
      'uri' => uri,
      'method' => method,
      'status' => status,
    }
    hash
  end
end
