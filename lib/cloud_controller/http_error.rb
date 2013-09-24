
class HttpError < StructuredError

  def initialize(msg, endpoint, response)
    @endpoint = endpoint
    @status = response.code.to_i

    begin
      error = Yajl::Parser.parse(response.body)
    rescue Yajl::ParseError
      error = response.body
    end

    super(msg, error)
  end

  def to_h
    hash = super
    hash['endpoint'] = @endpoint
    hash['status'] = @status
    hash
  end
end
