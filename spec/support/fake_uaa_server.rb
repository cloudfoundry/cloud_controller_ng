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
    ensure
      server.shutdown
    end
  end

  def stop
    server.shutdown
    thread.join(2)
    Thread.kill(thread)
  end
end

class UAAIssuer < WEBrick::HTTPServlet::AbstractServlet
  ISSUER = 'uaa_issuer'.freeze

  # rubocop:disable all
  def do_GET(_, response)
    # rubocop:enable all
    response.status          = 200
    response['Content-Type'] = 'application/json'
    response.body            = { issuer: ISSUER }.to_json
  end
end
