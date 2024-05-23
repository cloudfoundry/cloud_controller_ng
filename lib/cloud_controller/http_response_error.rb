require 'cloud_controller/structured_error'

class HttpResponseError < StructuredError
  attr_reader :uri, :method, :status, :response

  def initialize(message, method, response)
    @method = method.to_s.upcase
    @response = response
    @status = response.code.to_i

    begin
      source = Oj.load(response.body)
    rescue StandardError
      source = response.body
    end

    super(message, source)
  end

  def to_h
    hash = super
    hash['http'] = {
      'method' => method,
      'status' => status
    }
    hash
  end
end
