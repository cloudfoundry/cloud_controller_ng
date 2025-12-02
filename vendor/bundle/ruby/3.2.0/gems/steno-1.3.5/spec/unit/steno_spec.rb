require 'spec_helper'

describe Steno do
  let(:config) { Steno::Config.new }

  before do
    Steno.init(config)
  end

  describe '#logger' do
    it 'returns a new Steno::Logger instance' do
      logger = Steno.logger('test')
      expect(logger).not_to be_nil
      expect(logger.name).to eq('test')
    end

    it 'memoizes loggers by name' do
      logger1 = Steno.logger('test')
      logger2 = Steno.logger('test')

      expect(logger1.object_id).to eq(logger2.object_id)
    end
  end

  describe '#set_logger_regexp' do
    it 'modifies the levels of existing loggers that match the regex' do
      logger = Steno.logger('test')

      expect(logger.level).to eq(:info)

      Steno.set_logger_regexp(/te/, :debug)

      expect(logger.level).to eq(:debug)
    end

    it 'modifies the levels of new loggers after a regexp has been set' do
      Steno.set_logger_regexp(/te/, :debug)

      expect(Steno.logger('te').level).to eq(:debug)
    end

    it 'resets the levels of previously matching loggers when changed' do
      Steno.set_logger_regexp(/foo/, :debug)

      logger = Steno.logger('foo')
      expect(logger.level).to eq(:debug)

      Steno.set_logger_regexp(/bar/, :debug)

      expect(logger.level).to eq(:info)
    end
  end

  describe '#clear_logger_regexp' do
    it 'resets any loggers matching the existing regexp' do
      Steno.set_logger_regexp(/te/, :debug)

      logger = Steno.logger('test')
      expect(logger.level).to eq(:debug)

      Steno.clear_logger_regexp

      expect(logger.level).to eq(:info)
      expect(Steno.logger_regexp).to be_nil
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
        loggers << Steno.logger(name)
        loggers.last.level = level
      end

      expect(Steno.logger_level_snapshot).to eq(expected)
    end
  end
end
