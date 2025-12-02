require "spec_helper"
require "support/fake_loggregator_server"
require "loggregator_emitter"

class MessageFixture
  attr_reader :name, :message

  def initialize(name, message, server_threshold, no_server_threshold)
    @name = name
    @message = message
    @server_threshold = server_threshold
    @no_server_threshold = no_server_threshold
  end

  def expected(using_server)
    using_server ? @server_threshold : @no_server_threshold
  end
end

shared_examples "a performance test" do |fixture, using_server|
  let(:iterations) { using_server ? 100 : 1000 }

  before do
    @emitter = LoggregatorEmitter::Emitter.new("localhost:#{@free_port}", "origin", "API", 42)
    if !using_server
      @emitter.should_receive(:send_protobuffer).at_least(iterations).times
    end
  end

  it "emits #{fixture.name} within a time threshold #{using_server ? 'with' : 'without'} server", performance: true do
    start_time = Time.now.to_f

    iterations.times { @emitter.emit("my_app_id", fixture.message) }

    expect(Time.now.to_f - start_time).to be < fixture.expected(using_server)
  end

end

describe LoggregatorEmitter do
  @fixtures = []
  @fixtures << MessageFixture.new("long_message", (124*1024).times.collect { "a" }.join(""), 2.0, 2.0)
  @fixtures << MessageFixture.new("message with newlines", 10.times.collect { (6*1024).times.collect { "a" }.join("") + "\n" }.join(""), 3.0, 3.0)
  @fixtures << MessageFixture.new("message worst case", (124*1024).times.collect { "a" }.join("") + "\n", 2.0, 2.0)

  before :all do
    @free_port = 12346
    @server = FakeLoggregatorServer.new(@free_port)
    @server.start
  end

  after :all do
    @server.stop
  end


  [true, false].each do |using_server|
    @fixtures.each do |fixture|
      it_behaves_like "a performance test", fixture, using_server
    end
  end
end
