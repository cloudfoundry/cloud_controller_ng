require 'steno/steno'

RSpec.describe Steno::LoggerIO do
  let(:logger) { double(:logger) }
  let(:level) { :info }
  let(:logger_io) { described_class.new(logger, level) }

  describe '#write' do
    it 'writes to the logger' do
      expect(logger).to receive(:log).with(level, 'message')

      logger_io.write('message')
    end
  end

  describe '#sync' do
    it 'returns true' do
      expect(logger_io.sync).to be(true)
    end
  end

  context 'when writing a record' do
    let(:logger) { Steno::Logger.new('test', []) }

    it 'removes logger_io.rb from the callstack' do
      expect(Steno::Record).to receive(:new).and_wrap_original do |original_method, source, log_level, message, loc, data|
        expect(loc[0]).not_to match(/logger_io\.rb/)
        original_method.call(source, log_level, message, loc, data)
      end

      logger_io.write('message')
    end
  end
end
