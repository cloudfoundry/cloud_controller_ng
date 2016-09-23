require 'spec_helper'
require 'presenters/api_url_builder'

module VCAP::CloudController::Presenters
  RSpec.describe ApiUrlBuilder do
    let(:scheme) { TestConfig.config[:external_protocol] }
    let(:host) { TestConfig.config[:external_domain] }

    it 'builds a url when path is provided' do
      builder = ApiUrlBuilder.new

      expected_url = "#{scheme}://#{host}/v3/foo/bar"
      expect(builder.build_url(path: '/v3/foo/bar')).to eq expected_url
    end

    it 'can build urls with query string' do
      builder = ApiUrlBuilder.new

      expected_url = "#{scheme}://#{host}/v3/foo/bar?baz=quux"
      expect(builder.build_url(path: '/v3/foo/bar', query: 'baz=quux')).to eq expected_url
    end

    it 'builds a url without a trailing slash when path is NOT provided' do
      builder = ApiUrlBuilder.new

      expected_url = "#{scheme}://#{host}"
      expect(builder.build_url).to eq expected_url
    end
  end
end
