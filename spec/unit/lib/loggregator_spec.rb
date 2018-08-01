require 'spec_helper'

RSpec.describe Loggregator do
  describe 'when no emitter is set' do
    before { Loggregator.emitter = nil }

    it 'does not emit errors' do
      expect_any_instance_of(LoggregatorEmitter::Emitter).not_to receive(:emit_error)
      Loggregator.emit_error('app_id', 'error message')
    end

    it 'does not emit' do
      expect_any_instance_of(LoggregatorEmitter::Emitter).not_to receive(:emit)
      Loggregator.emit('app_id', 'log message')
    end
  end

  describe 'when the emitter is set' do
    it 'emits errors to the loggregator' do
      emitter = LoggregatorEmitter::Emitter.new('127.0.0.1:1234', 'cloud_controller', 'API', 1)
      expect(emitter).to receive(:emit_error).with('app_id', 'error message')
      Loggregator.emitter = emitter
      Loggregator.emit_error('app_id', 'error message')
    end

    it 'emits to the loggregator' do
      emitter = LoggregatorEmitter::Emitter.new('127.0.0.1:1234', 'cloud_controller', 'API', 1)
      expect(emitter).to receive(:emit).with('app_id', 'log message')
      Loggregator.emitter = emitter
      Loggregator.emit('app_id', 'log message')
    end
  end
end
