# Monkey patch to provide a robust read_request_body helper compatible with Rack 3
# See:
# https://github.com/zipmark/rspec_api_documentation/pull/550
# https://github.com/zipmark/rspec_api_documentation/issues/548

module RspecApiDocumentation
  class ClientBase
    def read_request_body
      input = last_request.env['rack.input'] || StringIO.new
      input.rewind
      input.read
    end
  end
end
