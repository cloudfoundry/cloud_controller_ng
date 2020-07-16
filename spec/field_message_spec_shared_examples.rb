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

  it 'validates `fields` is a hash' do
    message = described_class.from_params({ 'fields' => 'foo' }.with_indifferent_access)
    expect(message).not_to be_valid
    expect(message.errors[:fields][0]).to include('must be an object')
  end

  it 'does not accept fields resources that are not allowed' do
    message = described_class.from_params({ 'fields' => { 'space.foo': 'name' } })
    expect(message).not_to be_valid
    expect(message.errors[:fields]).to include(include(
                                                 '[space.foo] valid resources are:'
    ))
  end
end

RSpec.shared_examples 'fields query hash' do
  it 'validates `fields` is a hash' do
    message = described_class.from_params({ 'fields' => 'foo' }.with_indifferent_access)
    expect(message).not_to be_valid
    expect(message.errors[:fields][0]).to include('must be an object')
  end

  it 'does not accept fields resources that are not allowed' do
    message = described_class.from_params({ 'fields' => { 'space.foo': 'name' } })
    expect(message).not_to be_valid
    expect(message.errors[:fields]).to include(include(
                                                 '[space.foo] valid resources are:'
    ))
  end
end

RSpec.shared_examples 'fields to_param_hash' do |resource, keys|
  it 'correctly formats the fields' do
    expect(message.to_param_hash).to include("fields[#{resource}]": keys)
  end
end
