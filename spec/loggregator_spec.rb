require "spec_helper"

describe Loggregator do
  describe "when no emitter is set" do
    it "does not emit errors" do
      LoggregatorEmitter::Emitter.any_instance.should_not_receive(:emit_error)
      Loggregator.emit_error("app_id", "error message")
    end
    it "does not emit" do
      LoggregatorEmitter::Emitter.any_instance.should_not_receive(:emit)
      Loggregator.emit("app_id", "log message")
    end

  end
  describe "when the emitter is set" do
    it "emits errors to the loggregator" do
      emitter = LoggregatorEmitter::Emitter.new("127.0.0.1:1234", LogMessage::SourceType::CLOUD_CONTROLLER)
      emitter.should_receive(:emit_error).with("app_id", "error message")
      Loggregator.emitter = emitter
      Loggregator.emit_error("app_id", "error message")
    end
    it "emits to the loggregator" do
      emitter = LoggregatorEmitter::Emitter.new("127.0.0.1:1234", LogMessage::SourceType::CLOUD_CONTROLLER)
      emitter.should_receive(:emit).with("app_id", "log message")
      Loggregator.emitter = emitter
      Loggregator.emit("app_id", "log message")
    end
  end

end
