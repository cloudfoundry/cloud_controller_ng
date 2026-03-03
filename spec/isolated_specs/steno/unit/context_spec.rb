require 'steno/steno'
require_relative '../support/shared_context_specs'
require_relative '../support/barrier'

RSpec.describe Steno::Context do
  describe Steno::Context::Null do
    include_context 'steno context'

    let(:context) { described_class.new }

    it 'stores no data' do
      expect(context.data).to eq({})
      context.data['foo'] = 'bar'
      expect(context.data).to eq({})
    end
  end

  describe Steno::Context::ThreadLocal do
    include_context 'steno context'

    let(:context) { described_class.new }

    it 'stores data local to threads' do
      b1 = Barrier.new
      b2 = Barrier.new

      t1 = Thread.new do
        context.data['thread'] = 't1'
        b1.release
        b2.wait
        expect(context.data['thread']).to eq('t1')
      end

      t2 = Thread.new do
        b1.wait
        expect(context.data['thread']).to be_nil
        context.data['thread'] = 't2'
        b2.release
      end

      t1.join
      t2.join
    end
  end
end
