require 'cloud_controller/structured_error'

class HttpResponseError < StructuredError
  attr_reader :uri, :method, :status, :response

  def initialize(message, method, response)
    @method = method.to_s.upcase
    @response = response
    @status = response.code.to_i

    begin
      source = MultiJson.load(response.body)
    rescue ArgumentError
      # Either Oj should raise Oj::ParseError instead of ArgumentError, or MultiJson should also wrap
      # ArgumentError into MultiJson::Adapters::Oj::ParseError
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
