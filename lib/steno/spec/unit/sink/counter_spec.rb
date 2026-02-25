require 'spec_helper'

describe Steno::Sink::Counter do
  let(:level) do
    Steno::Logger.lookup_level(:info)
  end

  let(:record) do
    Steno::Record.new('source', level.name, 'message')
  end

  describe 'add_record' do
    it 'counts added records' do
      expect(subject.counts).to be_empty
      subject.add_record(record)
      expect(subject.counts.size).to eq 1
      expect(subject.counts['info']).to eq 1
    end
  end

  describe 'to_json' do
    it 'produces a valid json representation' do
      subject.add_record(record)
      expect(subject.to_json).to match '"info":1'
    end
  end
end
