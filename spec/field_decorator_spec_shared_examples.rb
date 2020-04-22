RSpec.shared_examples 'field decorator match?' do |resource, keys|
  keys.each do |key|
    it "matches hashes containing resource symbol `#{resource}` and value `#{key}`" do
      expect(described_class.match?({ "#{resource}": [key.to_s], other: ['bar'] })).to be_truthy
    end
  end

  it "matches hashes containing resource symbol `#{resource}` and all valid keys" do
    expect(described_class.match?({ "#{resource}": keys, other: ['bar'] })).to be_truthy
  end

  it 'does not match other values for a valid resource' do
    expect(described_class.match?({ "#{resource}": ['foo'] })).to be_falsey
  end

  it 'does not match other resource values' do
    expect(described_class.match?({ other: ['bar'] })).to be_falsey
  end

  it 'does not match non-hashes' do
    expect(described_class.match?('foo')).to be_falsey
  end
end
