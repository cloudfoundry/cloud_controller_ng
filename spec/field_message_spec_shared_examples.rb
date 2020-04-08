RSpec.shared_examples 'field query parameter' do |resource, keys|
  keys_list = keys.split(',')

  it "accepts the `fields` parameter with fields[#{resource}]=#{keys}" do
    message = described_class.from_params({ 'fields' => { "#{resource}": keys.to_s } })

    expect(message).to be_valid
    expect(message.requested?(:fields)).to be_truthy
    expect(message.fields).to match({ "#{resource}": keys_list })
  end

  keys_list.each do |key|
    it "accepts the `fields` parameter with fields[#{resource}]=#{key}" do
      message = described_class.from_params({ 'fields' => { "#{resource}": key.to_s } })

      expect(message).to be_valid
      expect(message.requested?(:fields)).to be_truthy
      expect(message.fields).to match({ "#{resource}": [key] })
    end
  end

  it "does not accept fields keys that are not #{keys}" do
    message = described_class.from_params({ 'fields' => { "#{resource}": "#{keys},foo" } })
    expect(message).not_to be_valid
    quoted_keys = keys_list.map { |k| "'#{k}'" }
    expect(message.errors[:fields]).to include("valid keys for '#{resource}' are: #{quoted_keys.join(', ')}")
  end
end
