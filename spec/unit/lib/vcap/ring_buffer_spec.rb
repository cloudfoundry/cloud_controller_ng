require 'spec_helper'
require 'vcap/ring_buffer'

module VCAP
  describe RingBuffer do
    MAX_ENTRIES = 5
    let(:rb) { RingBuffer.new(MAX_ENTRIES) }

    context 'empty' do
      it '.empty? should be true' do
        expect(rb.empty?).to be true
      end
    end

    context 'with max push MAX_ENTRIES times' do
      before do
        MAX_ENTRIES.times do |i|
          rb.push i
        end
      end

      it '.empty? should be false' do
        expect(rb.empty?).to be false
      end

      it '.size should return MAX_ENTRIES' do
        expect(rb.size).to eq(MAX_ENTRIES)
      end

      it 'should be in the correct order' do
        a = []
        MAX_ENTRIES.times { |i| a.push i }
        expect(rb).to eq(a)
      end

      it '.push should add a new entry and drop the old one' do
        rb.push 'a'
        expect(rb).to eq([1, 2, 3, 4, 'a'])
      end

      it '.<< should add a new entry and drop the old one' do
        rb << 'a'
        expect(rb).to eq([1, 2, 3, 4, 'a'])
      end
    end
  end
end
