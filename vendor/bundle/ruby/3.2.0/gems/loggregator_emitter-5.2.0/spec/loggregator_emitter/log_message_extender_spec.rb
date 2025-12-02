require "spec_helper"
require "rspec"
require "loggregator_emitter"

describe LogMessage do
  describe "#message_type_name" do
    it "returns STDOUT for type == 1" do
      msg = LogMessage.new(
        {
          :message => "thesearebytes",
          :message_type => 1,
          :timestamp => 3
        })

      expect(msg.message_type_name).to eq("STDOUT")
    end

    it "returns STDERR for type == 2" do
      msg = LogMessage.new(
        {
          :message => "thesearebytes",
          :message_type => 2,
          :timestamp => 3
        })

      expect(msg.message_type_name).to eq("STDERR")
    end
  end

  describe "#time=" do
    it "takes a time object" do
      msg = LogMessage.new
      msg.time = Time.utc(2010, 1, 20, 19, 18, 17.654321011)

      expect(msg.timestamp).to eq 1264015097654321011
    end
  end

  describe "#time" do
    it "returns a time object" do
      msg = LogMessage.new
      msg.timestamp = 1264015097654321011

      expect(msg.time).to be_a Time
    end

    it "returns a time object with nanosecond precision" do
      msg = LogMessage.new
      msg.timestamp = 1264015097654321011

      expect(msg.time.tv_nsec).to eq 654321011
    end
  end
end
