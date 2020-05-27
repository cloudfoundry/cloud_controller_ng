require 'spec_helper'
require 'fluent_emitter'

module VCAP
  RSpec.describe 'FluentEmitter' do
    let(:fluent_logger) { instance_double(::Fluent::Logger::FluentLogger) }
    subject { FluentEmitter.new(fluent_logger) }

    it 'emits app event logs to the fluent logger' do
      expect(fluent_logger).to receive(:post).with('API', {
        app_id: 'app_id',
        source_type: 'API',
        instance_id: '0',
        log: 'log message',
      }).and_return(true)

      subject.emit('app_id', 'log message')
    end

    it 'raises errors' do
      expect(fluent_logger).to receive(:post).and_return(false)
      expect(fluent_logger).to receive(:last_error)

      expect {
        subject.emit('bogus', 'log message')
      }.to raise_error(FluentEmitter::Error)
    end
  end
end
