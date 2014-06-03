require 'spec_helper'

describe StructuredError do
  context 'with a hash source' do
    let(:source) { { 'foo' => 'bar' } }

    it 'generates the correct hash' do
      exception = described_class.new('some msg', source)
      exception.set_backtrace(['/foo:1', '/bar:2'])

      expect(exception.to_h).to eq({
        'description' => "some msg",
        'backtrace' => ['/foo:1', '/bar:2'],
        'source' => source,
      })
    end
  end

  context 'with a nested exception source' do
    let(:source) do
      src = SocketError.new('something bad happened')
      src.set_backtrace(['/baz:1', '/asdf:2'])
      src
    end

    it 'generates the correct hash' do
      exception = described_class.new('some msg', source)

      source_hash = exception.to_h.fetch('source')
      expect(source_hash).to eq({
        'description' => 'something bad happened',
        'backtrace' => ['/baz:1', '/asdf:2']
      })
    end
  end

  context 'with another structured error source' do
    let(:source) do
      original_error = ZeroDivisionError.new('the universe implodes')
      original_error.set_backtrace(['/baz:1', '/asdf:2'])

      nested_error = StructuredError.new('pausing the world', original_error)
      nested_error.set_backtrace(['/qwer:1', '/zxcv:2'])

      nested_error
    end

    it 'generates the correct hash' do
      exception = described_class.new('some msg', source)

      source_hash = exception.to_h.fetch('source')
      expect(source_hash).to eq({
        'description' => 'pausing the world',
        'backtrace' => ['/qwer:1', '/zxcv:2'],
        'source' => {
          'description' => 'the universe implodes',
          'backtrace' => ['/baz:1', '/asdf:2']
        }
      })
    end
  end

  context 'with a simple string source' do
    let(:source) { 'foo' }

    it 'generates the correct hash' do
      exception = described_class.new('some msg', source)

      expect(exception.to_h.fetch('source')).to eq('foo')
    end
  end
end

