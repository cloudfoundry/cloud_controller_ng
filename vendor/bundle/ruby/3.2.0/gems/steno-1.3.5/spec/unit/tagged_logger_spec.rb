require 'spec_helper'

describe Steno::TaggedLogger do
  let(:sink) { NullSink.new }
  let(:logger) { Steno::Logger.new('test', [sink]) }
  let(:user_data) { { 'foo' => 'bar' } }
  let(:tagged_logger) { Steno::TaggedLogger.new(logger, user_data) }

  it 'adds any user data to each log record' do
    tagged_logger.info('testing', 'test' => 'data')
    expect(sink.records.size).to eq(1)
    expect(sink.records[0].data).to eq(user_data.merge('test' => 'data'))

    tagged_logger.log_exception(RuntimeError.new('hi'))
    expect(sink.records.size).to eq(2)
    expect(sink.records[1].data).to eq(user_data.merge(backtrace: nil))
  end

  it 'forwards missing methods to the proxied logger' do
    expect(tagged_logger.level).to eq(:info)
    tagged_logger.level = :warn

    expect(logger.level).to eq(:warn)

    expect(tagged_logger.level_active?(:info)).to be_falsey
  end

  describe '#tag' do
    it 'returns a new tagged logger with merged user-data' do
      tl = tagged_logger.tag('bar' => 'baz')
      expect(tl.proxied_logger).to eq(logger)
      expect(tl.user_data).to eq(user_data.merge('bar' => 'baz'))
    end
  end
end
