
class HttpError < StructuredError

  def initialize(msg, endpoint, method, response, code=nil)
    begin
      error = Yajl::Parser.parse(response.body)
    rescue Yajl::ParseError
      error = response.body
    end

    http_hash = {'http' => {'status' => response.code, 'uri' => endpoint, 'method' => method}}

    super(msg, error: error, code: code, :hash_to_merge => http_hash)
  end
end


class NonResponsiveHttpError < StructuredError

  def initialize(msg, error, endpoint, method, code=nil)

    http_hash = {'http' => {'uri' => endpoint, 'method' => method}}

    super(msg, error: error, code: code, :hash_to_merge => http_hash)
  end
end


