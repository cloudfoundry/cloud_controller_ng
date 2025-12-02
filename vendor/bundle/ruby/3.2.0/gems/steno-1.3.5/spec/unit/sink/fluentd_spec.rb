require 'spec_helper'

describe Steno::Sink::IO do
  let(:level) do
    Steno::Logger.lookup_level(:info)
  end

  let(:record) do
    Steno::Record.new('source', level.name, 'message')
  end

  describe '#initialize' do
    it 'initializes FluentLogger with the default option' do
      expect(Fluent::Logger::FluentLogger).to receive(:new).with('steno', {
                                                                   host: '127.0.0.1',
                                                                   port: 24_224,
                                                                   buffer_limit: Fluent::Logger::FluentLogger::BUFFER_LIMIT
                                                                 }).and_return(nil)
      sink = Steno::Sink::Fluentd.new
    end

    it 'initializes FliuentLogger with override options' do
      expect(Fluent::Logger::FluentLogger).to receive(:new).with('vcap', {
                                                                   host: 'localhost',
                                                                   port: 8080,
                                                                   buffer_limit: 1024
                                                                 }).and_return(nil)
      sink = Steno::Sink::Fluentd.new({
                                        tag_prefix: 'vcap',
                                        host: 'localhost',
                                        port: 8080,
                                        buffer_limit: 1024
                                      })
    end
  end

  describe '#add_record' do
    it 'posts an record with the correct tag' do
      fluentd = double('fluentd')
      expect(Fluent::Logger::FluentLogger).to receive(:new).and_return(fluentd)
      expect(fluentd).to receive(:post).with('source', record)
      sink = Steno::Sink::Fluentd.new
      sink.add_record(record)
    end
  end
end
