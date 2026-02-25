require 'spec_helper'
require_relative '../spec_helper'

require 'steno/core_ext'

module Foo
  class Bar
  end
end

RSpec.describe Module do
  describe '#logger' do
    it 'requests a logger named after itself' do
      x = Foo.logger
      expect(x).to be_a(Steno::Logger)
      expect(x.name).to include('Foo')
    end
  end
end

RSpec.describe Class do
  describe '#logger' do
    it 'requests a logger named after itself' do
      x = Foo::Bar.logger
      expect(x).to be_a(Steno::Logger)
      expect(x.name).to include('Foo::Bar')
    end
  end
end

RSpec.describe Object do
  describe '#logger' do
    it 'requests a logger named after its class' do
      x = Foo::Bar.new.logger
      expect(x).to be_a(Steno::Logger)
      expect(x.name).to include('Foo::Bar')
    end
  end
end
