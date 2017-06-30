require 'webrick'

class FakeUAAServer
  attr_reader :thread, :server

  def initialize(port)
    @server = WEBrick::HTTPServer.new(
      BindAddress: 'localhost',
      Port: port,
      AccessLog: [],
      Logger: WEBrick::Log.new('/dev/null')
    )

    server.mount '/.well-known/openid-configuration', UAAIssuer
  end

  def start
    @thread = Thread.new do
      server.start
    end
  end

  def stop
    server.shutdown
    Thread.kill(thread)
  end
end

class UAAIssuer < WEBrick::HTTPServlet::AbstractServlet
  # rubocop:disable all
  def do_GET(_, response)
    # rubocop:enable all
    response.status          = 200
    response['Content-Type'] = 'application/json'
    response.body            = { issuer: 'uaa_issuer' }.to_json
  end
end
