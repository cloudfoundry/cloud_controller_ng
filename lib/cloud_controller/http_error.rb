
class HttpError < StructuredError
  attr_reader :endpoint, :response, :method

  def initialize(endpoint, response, method)
    @endpoint = endpoint
    @response = response
    @method = method

    begin
      error = Yajl::Parser.parse(response.body)
    rescue Yajl::ParseError
      error = response.body
    end

    http_hash = {'http' => {'status' => response.code, 'uri' => endpoint, 'method' => method}}

    super(msg, error: error, code: code, :hash_to_merge => http_hash)
  end

  def code
    unless self.class.const_defined?(:CODE)
      raise "CODE required.  Please define constant #{self.class}::CODE as an integer matching v2.yml"
    end
    self.class::CODE
  end

  def msg
    raise "Error message required.  Please define #{self.class}#msg."
  end
end


class NonResponsiveHttpError < StructuredError
  attr_reader :endpoint, :nested_exception
  def initialize(endpoint, method, nested_exception)
    @nested_exception = nested_exception
    @endpoint = endpoint
    http_hash = {'http' => {'uri' => endpoint, 'method' => method}}
    super(msg, error: error, code: code, :hash_to_merge => http_hash)
  end

  def code
    unless self.class.const_defined?(:CODE)
      raise "CODE required.  Please define constant #{self.class}::CODE as an integer matching v2.yml"
    end
    self.class::CODE
  end

  def msg
    raise "Error message required.  Please define #{self.class}#msg."
  end

  def error
    types = nested_exception.class.ancestors.map(&:name) - Exception.ancestors.map(&:name)
    {
      'description' => nested_exception.message,
      'types' => types,
      'backtrace' => nested_exception.backtrace,
    }
  end
end


