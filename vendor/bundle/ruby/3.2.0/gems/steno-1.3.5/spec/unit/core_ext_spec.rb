require 'spec_helper'

require 'steno/core_ext'

module Foo
  class Bar
  end
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
