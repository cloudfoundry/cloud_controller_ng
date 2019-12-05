require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Info Request' do
  describe 'GET /v3/info' do
    let(:return_info_json) do
      {
        build: TestConfig.config[:info][:build],
        cli_version: {
          minimum: TestConfig.config[:info][:min_cli_version],
          recommended: TestConfig.config[:info][:min_recommended_cli_version]
        },
        custom: TestConfig.config[:info][:custom],
        description: TestConfig.config[:info][:description],
        name: TestConfig.config[:info][:name],
        version: TestConfig.config[:info][:version],
        links: {
          self: { href: "#{link_prefix}/v3/info" },
          support: { href: TestConfig.config[:info][:support_address] }
        }
      }
    end

    it 'includes data from the config' do
      get '/v3/info'
      expect(MultiJson.load(last_response.body)).to match_json_response(return_info_json)
    end

    context 'when no info values are set' do
      let(:return_info_json) do
        {
          build: '',
          cli_version: {
            minimum: '',
            recommended: ''
          },
          custom: {},
          description: '',
          name: '',
          version: 0,
          links: {
            self: { href: "#{link_prefix}/v3/info" },
            support: { href: '' }
          }
        }
      end

      before do
        TestConfig.override(info: nil)
      end

      it 'includes has proper empty values' do
        get '/v3/info'
        expect(MultiJson.load(last_response.body)).to match_json_response(return_info_json)
      end
    end
  end
end
