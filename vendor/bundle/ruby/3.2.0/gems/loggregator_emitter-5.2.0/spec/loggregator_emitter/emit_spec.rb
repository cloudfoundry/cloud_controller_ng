# encoding: UTF-8
require "spec_helper"
require "support/fake_loggregator_server"
require "loggregator_emitter"

describe LoggregatorEmitter do
  before do
    @free_port = test_port
    @server = FakeLoggregatorServer.new(@free_port)
  end

  before :each do
    @server.start
  end

  after :each do
    @server.stop
    @server.reset
  end

  def test_port
    server = TCPServer.new('localhost', 0)
    server.addr[1]
  end

  describe "configuring emitter" do
    describe "valid configurations" do
      it "is valid with IP and proper source name" do
        expect { LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "DEA") }.not_to raise_error
      end

      it "is valid with resolveable hostname and proper source name" do
        expect { LoggregatorEmitter::Emitter.new("localhost:#{@free_port}", "origin", "DEA") }.not_to raise_error
      end

      it "accepts a string as source type/name" do
        expect { LoggregatorEmitter::Emitter.new("localhost:#{@free_port}", "origin", "STG") }.not_to raise_error
      end
    end

    describe "invalid configurations" do
      describe "error based on loggregator_server" do
        it "raises if host has protocol" do
          expect { LoggregatorEmitter::Emitter.new("http://0.0.0.0:#{@free_port}", "origin", "DEA") }.to raise_error(ArgumentError)
        end

        it "raises if host is blank" do
          expect { LoggregatorEmitter::Emitter.new(":#{@free_port}", "origin", "DEA") }.to raise_error(ArgumentError)
        end

        it "raises if host is unresolvable" do
          expect { LoggregatorEmitter::Emitter.new("i.cant.resolve.foo:#{@free_port}", "origin", "DEA") }.to raise_error(ArgumentError)
        end

        it "raises if origin is blank" do
          expect { LoggregatorEmitter::Emitter.new(":#{@free_port}", "", "DEA") }.to raise_error(ArgumentError)
        end

        it "raises if source_type is an unknown integer" do
          expect { LoggregatorEmitter::Emitter.new("localhost:#{@free_port}", "origin", 7) }.to raise_error(ArgumentError)
        end

        it "raises if source_type is not an integer or string" do
          expect { LoggregatorEmitter::Emitter.new("localhost:#{@free_port}", "origin", nil) }.to raise_error(ArgumentError)
          expect { LoggregatorEmitter::Emitter.new("localhost:#{@free_port}", "origin", 12.0) }.to raise_error(ArgumentError)
        end

        it "raises if source_type is too large of a string" do
          expect { LoggregatorEmitter::Emitter.new("localhost:#{@free_port}", "origin", "ABCD") }.to raise_error(ArgumentError)
        end

        it "raises if source_type is too small of a string" do
          expect { LoggregatorEmitter::Emitter.new("localhost:#{@free_port}", "origin", "AB") }.to raise_error(ArgumentError)
        end
      end
    end
  end

  def test_tags(tags)
    expected_tags = []
    tags.each do |k, v|
      expected_tags << ::Sonde::Envelope::TagsEntry.new(:key => k, :value => v)
    end
    expected_tags
  end

  describe "max_tags" do
    it "throws an exception when there are more than 10 tags" do
      tags = {}
      for i in 0..10
        tags["tag#{i}"] = "value#{i}"
      end

      emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API", 42)

      Timecop.freeze timestamp do
        expect { emitter.emit("my_app_id", "Hello there!", tags) }.to raise_error(ArgumentError)
      end
    end
  end


  describe "max_tag_length" do
    it "throws an exception when the key is too long" do
      too_long = "x" * 257
      tag = {too_long => "a"}

      emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API", 42)

      Timecop.freeze timestamp do
        expect { emitter.emit("my_app_id", "Hello there!", tag) }.to raise_error(ArgumentError)
      end
    end

    it "throws an exception when the value is too long" do
      too_long = "x" * 257
      tag = {"a" => too_long}

      emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API", 42)

      Timecop.freeze timestamp do
        expect { emitter.emit("my_app_id", "Hello there!", tag) }.to raise_error(ArgumentError)
      end
    end

    it "counts multi-byte unicode characters as single characters when checking key length" do
      just_right = "x" * 255 + "Ω"
      tag = {just_right => "a"}

      emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API", 42)

      Timecop.freeze timestamp do
        expect { emitter.emit("my_app_id", "Hello there!", tag) }.not_to raise_error
      end
    end

    it "counts multi-byte unicode characters as single characters when checking value length" do
      just_right = "x" * 255 + "Ω"
      tag = {"a" => just_right}

      emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API", 42)

      Timecop.freeze timestamp do
        expect { emitter.emit("my_app_id", "Hello there!", tag) }.not_to raise_error
      end
    end
  end

  let(:timestamp) {Time.now}
  describe "emit_log_envelope" do
    def make_emitter(host)
      LoggregatorEmitter::Emitter.new("#{host}:#{@free_port}", "origin", "API", 42)
    end

    it "successfully writes envelope protobuffers" do
      tag = {"key1" => "value1"}
      emitter = make_emitter("0.0.0.0")
      Timecop.freeze timestamp do
        emitter.emit("my_app_id", "Hello there!", tag)
      end

      @server.wait_for_messages(1)

      messages = @server.messages

      expect(messages.length).to eq 1
      message = messages[0]

      expect(message.time).to be_within(1).of timestamp
      expect(message.logMessage.time).to be_within(1).of timestamp
      expect(message.logMessage.message).to eq "Hello there!"
      expect(message.logMessage.app_id).to eq "my_app_id"
      expect(message.logMessage.source_instance).to eq "42"
      expect(message.tags).to eq test_tags(tag)
      expect(message.logMessage.message_type).to eq ::Sonde::LogMessage::MessageType::OUT
    end

    it "successfully handles envelope with multiple tags" do
      tags = {"key1" => "value1", "key2" => "value2"}
      emitter = make_emitter("0.0.0.0")
      Timecop.freeze timestamp do
        emitter.emit("my_app_id", "Hello there!", tags)
      end

      @server.wait_for_messages(1)

      messages = @server.messages

      expect(messages.length).to eq 1
      message = messages[0]

      expect(message.tags).to eq test_tags(tags)
    end

    it "gracefully handles failures to send messages" do
      emitter = make_emitter("0.0.0.0")
      UDPSocket.any_instance.stub(:sendmsg_nonblock).and_raise("Operation not permitted - sendmsg(2) (Errno::EPERM)")

      expect {emitter.emit("my_app_id", "Hello there!")}.to raise_error(LoggregatorEmitter::Emitter::UDP_SEND_ERROR)
    end

    it "makes the right protobuffer" do
      emitter = make_emitter("0.0.0.0")

      message = nil
      emitter.stub(:send_protobuffer) do |arg|
        result = arg.encode.buf
        message = result.unpack("C*")
      end
      emitter.emit("my_app_id", "Hello there!")

      #This test is here to create arrays of bytes to be used in the golang emitter to verify that they are compatible.
      #One of the results we saw:
      #[10, 9, 109, 121, 95, 97, 112, 112, 95, 105, 100, 18, 96, 163, 227, 248, 110, 81, 17, 141, 224, 211, 132, 74, 230, 43, 169, 76, 169, 244, 119, 169, 212, 160, 121, 128, 89, 13, 149, 218, 136, 72, 217, 89, 226, 41, 57, 80, 77, 24, 152, 98, 120, 145, 125, 29, 239, 34, 26, 20, 162, 137, 215, 170, 121, 185, 167, 221, 161, 139, 87, 139, 102, 152, 137, 11, 232, 137, 227, 74, 252, 166, 44, 176, 208, 6, 131, 15, 250, 43, 193, 233, 254, 189, 26, 194, 237, 43, 35, 97, 123, 156, 215, 47, 201, 228, 136, 210, 245, 26, 43, 10, 12, 72, 101, 108, 108, 111, 32, 116, 104, 101, 114, 101, 33, 16, 1, 24, 224, 175, 235, 159, 154, 239, 210, 177, 38, 34, 9, 109, 121, 95, 97, 112, 112, 95, 105, 100, 40, 1, 50, 2, 52, 50]
    end
  end

  describe "#emit_value_metric" do
    let(:emitter) { LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "DEA")}

    it 'successfully writes envelope protobuffers' do
      tag = {"key1" => "value1"}
      Timecop.freeze timestamp do
        emitter.emit_value_metric('my-metric', 5155, 'my-units', tag)
      end

      @server.wait_for_messages(1)
      messages = @server.messages

      expect(messages.length).to eq 1
      message = messages[0]

      expect(message.time).to be_within(1).of(timestamp)
      expect(message.valueMetric.value).to eq(5155)
      expect(message.valueMetric.name).to eq('my-metric')
      expect(message.valueMetric.unit).to eq('my-units')
      expect(message.tags).to eq test_tags(tag)
    end

    it "successfully handles envelope with multiple tags" do
      tags = {"key1" => "value1", "key2" => "value2"}
      Timecop.freeze timestamp do
        emitter.emit_value_metric('my-metric', 5155, 'my-units', tags)
      end

      @server.wait_for_messages(1)
      messages = @server.messages

      expect(messages.length).to eq 1
      message = messages[0]

      expect(message.tags).to eq test_tags(tags)
    end
  end

  describe "#emit_counter" do
    let(:emitter) { LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "DEA")}

    it 'successfully writes envelope protobuffers' do
      tag = {"key1" => "value1"}
      Timecop.freeze timestamp do
        emitter.emit_counter('my-counter', 5, tag)
      end

      @server.wait_for_messages(1)

      messages = @server.messages

      expect(messages.length).to eq 1
      message = messages[0]

      expect(message.time).to be_within(1).of(timestamp)
      expect(message.counterEvent.delta).to eq(5)
      expect(message.counterEvent.name).to eq('my-counter')
      expect(message.tags).to eq test_tags(tag)
    end

    it "successfully handles envelope with multiple tags" do
      tags = {"key1" => "value1", "key2" => "value2"}
      Timecop.freeze timestamp do
        emitter.emit_counter('my-counter', 5, tags)
      end

      @server.wait_for_messages(1)

      messages = @server.messages

      expect(messages.length).to eq 1
      message = messages[0]

      expect(message.tags).to eq test_tags(tags)
    end
  end

  describe "#emit_container_metric" do
    let(:emitter) { LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "DEA")}

    it 'successfully writes envelope protobuffers' do
      tag = {"key1" => "value1"}
      Timecop.freeze timestamp do
        emitter.emit_container_metric('app-id', 3, 1.3, 1024, 2048, tag)
      end

      @server.wait_for_messages(1)

      messages = @server.messages

      expect(messages.length).to eq 1
      message = messages[0]

      expect(message.time).to be_within(1).of(timestamp)
      expect(message.containerMetric.applicationId).to eq('app-id')
      expect(message.containerMetric.instanceIndex).to eq(3)
      expect(message.containerMetric.cpuPercentage).to eq(1.3)
      expect(message.containerMetric.memoryBytes).to eq(1024)
      expect(message.containerMetric.diskBytes).to eq(2048)
      expect(message.tags).to eq test_tags(tag)
    end

    it "successfully handles envelope with multiple tags" do
      tags = {"key1" => "value1", "key2" => "value2"}
      Timecop.freeze timestamp do
        emitter.emit_container_metric('app-id', 3, 1.3, 1024, 2048, tags)
      end

      @server.wait_for_messages(1)

      messages = @server.messages

      expect(messages.length).to eq 1
      message = messages[0]

      expect(message.time).to be_within(1).of(timestamp)
      expect(message.containerMetric.applicationId).to eq('app-id')
      expect(message.containerMetric.instanceIndex).to eq(3)
      expect(message.containerMetric.cpuPercentage).to eq(1.3)
      expect(message.containerMetric.memoryBytes).to eq(1024)
      expect(message.containerMetric.diskBytes).to eq(2048)
      expect(message.tags).to eq test_tags(tags)
    end
  end

  {"emit" => LogMessage::MessageType::OUT, "emit_error" => LogMessage::MessageType::ERR}.each do |emit_method, message_type|
    describe "##{emit_method}" do
      def make_emitter(host)
        LoggregatorEmitter::Emitter.new("#{host}:#{@free_port}", "origin", "API", 42)
      end

      it "successfully writes protobuffers using ipv4" do
        emitter = make_emitter("127.0.0.1")
        emitter.send(emit_method, "my_app_id", "Hello there!")
        emitter.send(emit_method, "my_app_id", "Hello again!")
        emitter.send(emit_method, nil, "Hello again!")

        @server.wait_for_messages(2)

        messages = @server.messages

        expect(messages.length).to eq 2
        message = messages[0].logMessage
        expect(message.message).to eq "Hello there!"
        expect(message.app_id).to eq "my_app_id"
        expect(message.source_instance).to eq "42"
        expect(message.message_type).to eq message_type

        message = messages[1].logMessage
        expect(message.message).to eq "Hello again!"
      end

      it "successfully writes protobuffers using ipv6" do
        emitter = make_emitter("::1")
        emitter.send(emit_method, "my_app_id", "Hello there!")

        @server.wait_for_messages(1)

        messages = @server.messages
        expect(messages.length).to eq 1
        expect(messages[0].logMessage.message).to eq "Hello there!"
      end

      it "successfully writes protobuffers using a dns name" do
        emitter = make_emitter("localhost")
        emitter.send(emit_method, "my_app_id", "Hello there!")

        @server.wait_for_messages(1)

        messages = @server.messages
        expect(messages.length).to eq 1
        expect(messages[0].logMessage.message).to eq "Hello there!"
      end

      it "swallows empty messages" do
        emitter = make_emitter("localhost")
        emitter.send(emit_method, "my_app_id", nil)
        emitter.send(emit_method, "my_app_id", "")
        emitter.send(emit_method, "my_app_id", "   ")

        sleep 0.5

        messages = @server.messages
        expect(messages.length).to eq 0
      end

      it "truncates large messages" do
        emitter = make_emitter("localhost")
        message = (124*1024).times.collect { "a" }.join("")
        emitter.send(emit_method, "my_app_id", message)

        sleep 0.5

        messages = @server.messages
        expect(messages.length).to eq 1
        logMessage = messages[0].logMessage
        expect(logMessage.message.bytesize <= LoggregatorEmitter::Emitter::MAX_MESSAGE_BYTE_SIZE).to be true
        expect(logMessage.message.slice(-9..-1)).to eq("TRUNCATED")
      end

      it "splits messages by newlines" do
        emitter = make_emitter("localhost")
        message = "hi\n\rworld\nhow are you\r\ndoing\r"
        emitter.send(emit_method, "my_app_id", message)

        sleep 0.5
        messages = @server.messages
        expect(messages.length).to eq 4
      end

      it "sends messages with unicode characters " do
        emitter = make_emitter("localhost")
        message = "測試".encode("utf-8")
        emitter.send(emit_method, "my_app_id", message)

        sleep 0.5

        messages = @server.messages
        expect(messages.length).to eq 1
        expect(messages[0].logMessage.message.force_encoding("utf-8")).to eq "測試"
      end
    end
  end

  describe "source" do

    let(:emit_message) do
      @emitter.emit_error("my_app_id", "Hello there!")

      @server.wait_for_messages(2)

      @server.messages[0].logMessage
    end

    it "when type is known" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API")
      expect(emit_message.source_type).to eq "API"
    end

    it "when type is unknown" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "STG")
      expect(emit_message.source_type).to eq "STG"
    end

    it "id can be nil" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API")
      expect(emit_message.source_instance).to eq nil
    end

    it "id can be passed in as a string" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API", "some_source_id")
      expect(emit_message.source_instance).to eq "some_source_id"
    end

    it "id can be passed in as an integer" do
      @emitter = LoggregatorEmitter::Emitter.new("0.0.0.0:#{@free_port}", "origin", "API", 13)
      expect(emit_message.source_instance).to eq "13"
    end
  end
end
