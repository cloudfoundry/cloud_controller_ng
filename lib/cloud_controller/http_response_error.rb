require 'cloud_controller/structured_error'

class HttpResponseError < StructuredError
  attr_reader :uri, :method, :status

  def initialize(message, method, response)
    @method = method.to_s.upcase
    @status = response.code.to_i

    begin
      source = MultiJson.load(response.body)
    rescue MultiJson::ParseError
      source = response.body
    end

    super(message, source)
  end

  def to_h
    hash = super
    hash['http'] = {
      'method' => method,
      'status' => status,
    }
    hash
  end
end
