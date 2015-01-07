require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Info', type: [:api, :legacy_api] do
  get '/v2/info' do
    example 'Get Info' do
      do_request
      expect(status).to eq(200)
    end
  end
end
