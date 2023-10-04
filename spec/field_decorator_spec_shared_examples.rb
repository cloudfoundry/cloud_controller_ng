RSpec.shared_examples 'field decorator match?' do |resource, keys|
  keys.each do |key|
    it "matches hashes containing resource symbol `#{resource}` and value `#{key}`" do
      expect(described_class).to be_match({ "#{resource}": [key.to_s], other: ['bar'] })
    end
  end

  it "matches hashes containing resource symbol `#{resource}` and all valid keys" do
    expect(described_class).to be_match({ "#{resource}": keys, other: ['bar'] })
  end

  it 'does not match other values for a valid resource' do
    expect(described_class).not_to be_match({ "#{resource}": ['foo'] })
  end

  it 'does not match other resource values' do
    expect(described_class).not_to be_match({ other: ['bar'] })
  end

  it 'does not match non-hashes' do
    expect(described_class).not_to be_match('foo')
  end
end
