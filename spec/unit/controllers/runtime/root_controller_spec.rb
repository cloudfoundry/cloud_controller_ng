require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::RootController do
    describe 'GET /' do
      it 'returns a link to itself' do
        get '/'
        hash = Oj.load(last_response.body)
        expected_uri = link_prefix.to_s
        expect(hash['links']['self']['href']).to eq(expected_uri)
      end

      it 'returns a cloud controller v2 link with metadata' do
        get '/'
        hash = Oj.load(last_response.body)
        expected_uri = "#{link_prefix}/v2"
        expect(hash['links']['cloud_controller_v2']).to eq(
          {
            'href' => expected_uri,
            'meta' => {
              'version' => VCAP::CloudController::Constants::API_VERSION
            }
          }
        )
      end

      context 'temporary_enable_v2 is false' do
        before do
          TestConfig.override(temporary_enable_v2: false)
        end

        it 'returns no cloud controller v2 link with metadata' do
          get '/'
          hash = Oj.load(last_response.body)
          expect(hash['links']['cloud_controller_v2']).to be_nil
        end
      end

      it 'returns a cloud controller v3 link with metadata' do
        get '/'
        hash = Oj.load(last_response.body)
        expected_uri = "#{link_prefix}/v3"
        expect(hash['links']['cloud_controller_v3']).to eq(
          {
            'href' => expected_uri,
            'meta' => {
              'version' => VCAP::CloudController::Constants::API_VERSION_V3
            }
          }
        )
      end

      it 'returns a link to login service' do
        get '/'
        hash = Oj.load(last_response.body)
        expect(hash['links']['login']['href']).to eq(TestConfig.config[:login][:url])
      end

      it 'returns a link to UAA' do
        get '/'
        hash = Oj.load(last_response.body)
        expect(hash['links']['uaa']['href']).to eq(TestConfig.config[:uaa][:url])
      end

      describe 'credhub link' do
        context 'credhub external_url is configured' do
          before do
            TestConfig.override(credhub_api: { external_url: 'http://credhub.external.com' })
          end

          it 'returns a link' do
            get '/'
            hash = Oj.load(last_response.body)
            expect(hash['links']['credhub']['href']).to eq('http://credhub.external.com')
          end
        end

        context 'credhub external_url is not configured' do
          before do
            TestConfig.override(credhub_api: { some: 'prop' })
          end

          it 'does not return a link' do
            get '/'
            hash = Oj.load(last_response.body)
            expect(hash['links']['credhub']).to be_nil
          end
        end
      end

      describe 'routing link' do
        context 'routing_api is configured' do
          it 'returns a link' do
            TestConfig.override(routing_api: { url: 'some_routing_api' })
            get '/'
            hash = Oj.load(last_response.body)
            expect(hash['links']['routing']['href']).to eq('some_routing_api')
          end
        end

        context 'routing_api is not configured' do
          before do
            TestConfig.override(routing_api: nil)
          end

          it 'does not return a link' do
            get '/'
            hash = Oj.load(last_response.body)
            expect(hash['links']['routing']).to be_nil
          end
        end
      end

      it 'returns a link to network-policy v0 API' do
        get '/'
        hash = Oj.load(last_response.body)
        expected_uri = "#{link_prefix}/networking/v0/external"
        expect(hash['links']['network_policy_v0']['href']).to eq(expected_uri)
      end

      it 'returns a link to network-policy v1 API' do
        get '/'
        hash = Oj.load(last_response.body)
        expected_uri = "#{link_prefix}/networking/v1/external"
        expect(hash['links']['network_policy_v1']['href']).to eq(expected_uri)
      end

      it 'returns a link to the logging API' do
        expected_uri = 'wss://doppler.my-super-cool-cf.com:1234'
        TestConfig.override(doppler: { url: expected_uri })

        get '/'
        hash = Oj.load(last_response.body)
        expect(hash['links']['logging']['href']).to eq(expected_uri)
      end

      it 'returns a link to the log cache API' do
        expected_uri = 'https://log-cache.example.com'

        get '/'
        hash = Oj.load(last_response.body)
        expect(hash['links']['log_cache']['href']).to eq(expected_uri)
      end

      it 'returns a link to the v2 logging API' do
        expected_uri = 'https://log-stream.example.com'

        get '/'
        hash = Oj.load(last_response.body)
        expect(hash['links']['log_stream']['href']).to eq(expected_uri)
      end

      it 'returns a link for app_ssh with metadata' do
        expected_ssh_endpoint = 'ssh://ssh.example.org:2222'
        expected_host_key_fingerprint = 'the-host-key-fingerprint'
        expected_ssh_oauth_client = 'ssh-proxy'
        TestConfig.override(
          info: {
            app_ssh_endpoint: expected_ssh_endpoint,
            app_ssh_host_key_fingerprint: expected_host_key_fingerprint,
            app_ssh_oauth_client: expected_ssh_oauth_client
          }
        )

        get '/'
        hash = Oj.load(last_response.body)
        expect(hash['links']['app_ssh']).to eq(
          'href' => expected_ssh_endpoint,
          'meta' => {
            'host_key_fingerprint' => expected_host_key_fingerprint,
            'oauth_client' => expected_ssh_oauth_client
          }
        )
      end

      describe 'custom links' do
        context 'custom links are configured' do
          it 'returns a link' do
            TestConfig.override(custom_root_links: [{ name: 'custom_link_1', href: 'custom_link_1.com' }, { name: 'custom_link_2', href: 'custom_link_2.com' }])
            get '/'
            hash = Oj.load(last_response.body)
            expect(hash['links']['custom_link_1']['href']).to eq('custom_link_1.com')
            expect(hash['links']['custom_link_2']['href']).to eq('custom_link_2.com')
          end
        end

        context 'custom links overrides an existing link' do
          it 'returns the custom link' do
            TestConfig.override(custom_root_links: [{ name: 'uaa', href: 'my_new_uaa.com' }])
            get '/'
            hash = Oj.load(last_response.body)
            expect(hash['links']['uaa']['href']).to eq('my_new_uaa.com')
          end
        end
      end
    end
  end
end
