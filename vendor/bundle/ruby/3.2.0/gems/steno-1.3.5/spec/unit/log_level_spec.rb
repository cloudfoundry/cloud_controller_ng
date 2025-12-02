require 'spec_helper'

describe Steno::LogLevel do
  let(:info_level) { Steno::LogLevel.new(:info, 2) }
  let(:debug_level) { Steno::LogLevel.new(:debug, 1) }

  it 'is comparable' do
    expect(info_level > debug_level).to be_truthy
    expect(debug_level > info_level).to be_falsey
    expect(info_level == info_level).to be_truthy
  end

  describe '#to_s' do
    it 'returns the name of the level' do
      expect(info_level.to_s).to eq('info')
    end
  end
end
