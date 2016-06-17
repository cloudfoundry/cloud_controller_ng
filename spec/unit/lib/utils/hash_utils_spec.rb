require 'utils/hash_utils'

RSpec.describe HashUtils do
  describe 'dig' do
    it 'returns nested value' do
      hash = { foo: { bar: { baz: { qux: true } } } }
      expect(HashUtils.dig(hash, :foo, :bar, :baz, :qux)).to be_truthy
    end

    it 'returns partial digs' do
      hash = { foo: { bar: { baz: { qux: true } } } }
      expect(HashUtils.dig(hash, :foo, :bar)).to eq({ baz: { qux: true } })
    end

    it 'works for string and symbol keys' do
      hash = { foo: { bar: { 'baz' => { qux: true } } } }
      expect(HashUtils.dig(hash, :foo, :bar, 'baz', :qux)).to be_truthy
    end

    it 'returns nil if there is a missing key' do
      hash = { foo: { bar: { baz: { qux: true } } } }
      expect(HashUtils.dig(hash, :foo, :bar, :pants, :qux)).to be_nil
    end

    it 'returns nil if you dig too deep' do
      hash = { foo: { bar: { baz: { qux: true } } } }
      expect(HashUtils.dig(hash, :foo, :bar, :baz, :qux, :the_core)).to be_nil
    end
  end
end
