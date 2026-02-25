require 'spec_helper'

describe Steno do
  let(:config) { Steno::Config.new }

  before do
    described_class.init(config)
  end

  describe '#logger' do
    it 'returns a new Steno::Logger instance' do
      logger = described_class.logger('test')
      expect(logger).not_to be_nil
      expect(logger.name).to eq('test')
    end

    it 'memoizes loggers by name' do
      logger1 = described_class.logger('test')
      logger2 = described_class.logger('test')

      expect(logger1.object_id).to eq(logger2.object_id)
    end
  end

  describe '#set_logger_regexp' do
    it 'modifies the levels of existing loggers that match the regex' do
      logger = described_class.logger('test')

      expect(logger.level).to eq(:info)

      described_class.set_logger_regexp(/te/, :debug)

      expect(logger.level).to eq(:debug)
    end

    it 'modifies the levels of new loggers after a regexp has been set' do
      described_class.set_logger_regexp(/te/, :debug)

      expect(described_class.logger('te').level).to eq(:debug)
    end

    it 'resets the levels of previously matching loggers when changed' do
      described_class.set_logger_regexp(/foo/, :debug)

      logger = described_class.logger('foo')
      expect(logger.level).to eq(:debug)

      described_class.set_logger_regexp(/bar/, :debug)

      expect(logger.level).to eq(:info)
    end
  end

  describe '#clear_logger_regexp' do
    it 'resets any loggers matching the existing regexp' do
      described_class.set_logger_regexp(/te/, :debug)

      logger = described_class.logger('test')
      expect(logger.level).to eq(:debug)

      described_class.clear_logger_regexp

      expect(logger.level).to eq(:info)
      expect(described_class.logger_regexp).to be_nil
    end
  end

  describe '#logger_level_snapshot' do
    it 'returns a hash mapping logger name to level' do
      loggers = []

      expected = {
        'foo' => :debug,
        'bar' => :warn
      }

      expected.each do |name, level|
        # Prevent GC
        loggers << described_class.logger(name)
        loggers.last.level = level
      end

      expect(described_class.logger_level_snapshot).to eq(expected)
    end
  end
end
