
class HttpError < StructuredError

  def initialize(msg, endpoint, response)
    @endpoint = endpoint
    @status = response.code.to_i

    begin
      source = Yajl::Parser.parse(response.body)
    rescue Yajl::ParseError
      source = response.body
    end

    super(msg, source)
  end

  def to_h
    hash = super
    hash['endpoint'] = @endpoint
    hash['status'] = @status
    hash
  end
end
