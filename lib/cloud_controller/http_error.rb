
class HttpError < StructuredError

  def initialize(msg, response)
    begin
      error = Yajl::Parser.parse(response.body)
    rescue Yajl::ParseError
      error = response.body
    end

    super(msg, error)
  end
end
