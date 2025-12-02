require 'spec_helper'

describe Steno::Logger do
  let(:logger) { Steno::Logger.new('test', []) }

  it 'provides #level, #levelf, and #level? methods for each log level' do
    Steno::Logger::LEVELS.each do |name, _|
      [name, name.to_s + 'f', name.to_s + '?'].each do |meth|
        expect(logger.respond_to?(meth)).to be_truthy
      end
    end
  end

  describe '#level_active?' do
    it 'returns a boolean indicating if the level is enabled' do
      expect(logger.level_active?(:error)).to be_truthy
      expect(logger.level_active?(:info)).to be_truthy
      expect(logger.level_active?(:debug)).to be_falsey
    end
  end

  describe '#<level>?' do
    it 'returns a boolean indiciating if <level> is enabled' do
      expect(logger.error?).to be_truthy
      expect(logger.info?).to be_truthy
      expect(logger.debug?).to be_falsey
    end
  end

  describe '#level' do
    it 'returns the name of the currently active level' do
      expect(logger.level).to eq(:info)
    end
  end

  describe '#level=' do
    it 'allows the level to be changed' do
      logger.level = :warn
      expect(logger.level).to eq(:warn)
      expect(logger.level_active?(:info)).to be_falsey
      expect(logger.level_active?(:warn)).to be_truthy
    end
  end

  describe '#log' do
    it 'does not forward any messages for levels that are inactive' do
      sink = double('sink')
      expect(sink).not_to receive(:add_record)

      my_logger = Steno::Logger.new('test', [sink])

      my_logger.debug('test')
    end

    it 'forwards messages for levels that are active' do
      sink = double('sink')
      expect(sink).to receive(:add_record).with(any_args)

      my_logger = Steno::Logger.new('test', [sink])

      my_logger.warn('test')
    end

    it 'does not invoke a supplied block if the level is inactive' do
      invoked = false
      logger.debug { invoked = true }
      expect(invoked).to be_falsey
    end

    it 'invokes a supplied block if the level is active' do
      invoked = false
      logger.warn { invoked = true }
      expect(invoked).to be_truthy
    end

    it 'creates a record with the proper level' do
      sink = double('sink')
      expect(Steno::Record).to receive(:new).with('test', :warn, 'message', anything, anything).and_call_original
      allow(sink).to receive(:add_record)

      my_logger = Steno::Logger.new('test', [sink])

      my_logger.warn('message')
    end
  end

  describe '#logf' do
    it 'formats messages according to the supplied format string' do
      expect(logger).to receive(:log).with(:debug, 'test 1 2.20')
      logger.debugf('test %d %0.2f', 1, 2.2)
    end
  end

  describe '#tag' do
    it 'returns a tagged logger' do
      tagged_logger = logger.tag('foo' => 'bar')
      expect(tagged_logger).not_to be_nil
      expect(tagged_logger.user_data).to eq({ 'foo' => 'bar' })
    end
  end
end
