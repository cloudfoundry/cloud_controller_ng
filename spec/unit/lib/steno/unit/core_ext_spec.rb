require 'steno'

require 'steno/core_ext'

RSpec.describe 'Steno::CoreExt' do
  module Foo
    # rubocop:disable Lint/EmptyClass
    class Bar
    end
    # rubocop:enable Lint/EmptyClass
  end

  describe Module do
    describe '#logger' do
      it 'requests a logger named after itself' do
        x = Foo.logger
        expect(x).to be_a(Steno::Logger)
        expect(x.name).to include('Foo')
      end
    end
  end

  describe Class do
    describe '#logger' do
      it 'requests a logger named after itself' do
        x = Foo::Bar.logger
        expect(x).to be_a(Steno::Logger)
        expect(x.name).to include('Foo::Bar')
      end
    end
  end

  describe Object do
    describe '#logger' do
      it 'requests a logger named after its class' do
        x = Foo::Bar.new.logger
        expect(x).to be_a(Steno::Logger)
        expect(x.name).to include('Foo::Bar')
      end
    end
  end
end
