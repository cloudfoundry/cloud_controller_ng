require 'spec_helper'

RSpec.describe 'rspec_api_documentation gem version' do
  it 'is pinned to 6.1.0 for the monkey patch compatibility' do
    spec = Gem.loaded_specs['rspec_api_documentation']
    # Ensure the gem is loaded; spec_helper requires it in init block.
    expect(spec).not_to be_nil
    expect(spec.version.to_s).to eq('6.1.0')
  end
end
