require 'spec_helper'

module Foo
  module Bar
    class BadError < SocketError
    end
  end
end

describe Hashify do
  describe '#exception' do
    it 'turns an exception into a hash' do
      error = Foo::Bar::BadError.new("error description")
      error.set_backtrace(['foo', 'bar'])

      expect(Hashify.exception(error)).to eq({
        'description' => 'error description',
        'types' => ['BadError', 'SocketError'],
        'backtrace' => ['foo', 'bar']
      })
    end
  end

  describe '#types' do
    it 'provides the type hierarchy, stripping namespaces' do
      expect(Hashify.types(Foo::Bar::BadError.new)).to eq(['BadError', 'SocketError'])
    end
  end

  describe '#demodulize' do
    it 'strips off modules from class names' do
      expect(Hashify.demodulize(Foo::Bar::BadError)).to eq('BadError')
    end

    context 'classes without modules' do
      it 'leaves the class name alone' do
        expect(Hashify.demodulize(SocketError)).to eq('SocketError')
      end
    end
  end
end

