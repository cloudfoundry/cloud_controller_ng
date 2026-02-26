require 'steno'

RSpec.describe Steno do
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
end
