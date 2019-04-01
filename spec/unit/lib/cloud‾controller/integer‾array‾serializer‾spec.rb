require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IntegerArraySerializer do
    it 'should register with sequel' do
      expect(Sequel::Plugins::Serialization).to receive(:register_format)
      class Foo; extend IntegerArraySerializer; end
    end

    describe '.serializer' do
      let(:serializer) { IntegerArraySerializer.serializer }

      it 'raises an error when not passed an array' do
        (expect { serializer.call('hello') }).to raise_error(ArgumentError, 'Integer array columns must be passed an array')
      end

      it 'raises an error when not passed an array of integers' do
        (expect { serializer.call([1, 2, 'derp']) }).to raise_error(ArgumentError, 'All members of the array must be integers')
      end

      it 'does not raise an error if passed nil' do
        (expect { serializer.call(nil) }).not_to raise_error
      end

      it 'munges arrays to be in an expected comma-separated format' do
        expect(serializer.call([1, 2, 3, 4, 5])).to eq('1,2,3,4,5')
        expect(serializer.call([1])).to eq('1')
      end

      it 'serializes an empty array as an empty string' do
        expect(serializer.call([])).to eq('')
      end
    end

    describe '.deserializer' do
      let(:serializer) { IntegerArraySerializer.deserializer }

      it 'returns nil when passed nil' do
        expect(serializer.call(nil)).to eq(nil)
      end

      it 'returns an empty array when passed an empty string' do
        expect(serializer.call('')).to eq([])
      end

      it 'returns an array of integers when passed a non-arrayed string of one integer' do
        expect(serializer.call('1000')).to eq([1000])
      end

      it "returns an array of integers when passed Sequel's array-as-string format" do
        expect(serializer.call('1,2,3')).to eq([1, 2, 3])
      end
    end
  end
end
