require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe HttpClient do
    let(:auth_username) { 'me' }
    let(:auth_password) { 'abc123' }
    let(:request_id) { Sham.guid }
    let(:plan_id) { Sham.guid }
    let(:service_id) { Sham.guid }
    let(:instance_id) { Sham.guid }
    let(:url) { 'http://broker.example.com' }
    let(:full_url) { "http://broker.example.com#{path}" }
    let(:basic_auth) { [auth_username, auth_password] }
    let(:path) { '/the/path' }
    let(:fake_logger) { nil }

    subject(:client) do
      HttpClient.new(
        {
          url: url,
          auth_username: auth_username,
          auth_password: auth_password,
        },
        fake_logger
      )
    end

    before do
      allow(VCAP::Request).to receive(:current_id).and_return(request_id)
    end

    shared_examples 'a basic successful request' do
      let(:fake_logger) { instance_double(Steno::Logger, debug: nil) }

      describe 'returning a correct response object' do
        subject { make_request }

        its(:code) { should eq(200) }
        its(:body) { should_not be_nil }
      end

      it 'sets X-Broker-Api-Version header correctly' do
        make_request
        expect(a_request(http_method, full_url).
          with(basic_auth: basic_auth).
          with(query: hash_including({})).
          with(headers: { 'X-Broker-Api-Version' => '2.15' })).
          to have_been_made
      end

      it 'sets the X-Vcap-Request-Id header to the current request id' do
        make_request
        expect(a_request(http_method, full_url).
          with(basic_auth: basic_auth).
          with(query: hash_including({})).
          with(headers: { 'X-Vcap-Request-Id' => request_id })).
          to have_been_made
      end

      it 'sets the Accept header to application/json' do
        make_request
        expect(a_request(http_method, full_url).
          with(basic_auth: basic_auth).
          with(query: hash_including({})).
          with(headers: { 'Accept' => 'application/json' })).
          to have_been_made
      end

      it 'sets the X-Api-Info-Location header to the /v2/info endpoint at the external address' do
        make_request
        expect(a_request(http_method, full_url).
          with(basic_auth: basic_auth).
          with(query: hash_including({})).
          with(headers: { 'X-Api-Info-Location' => "#{TestConfig.config[:external_domain]}/v2/info" })).
          to have_been_made
      end

      it 'logs the default headers' do
        make_request
        expect(fake_logger).to have_received(:debug).with(match(%r{Accept"=>"application/json}))
        expect(fake_logger).to have_received(:debug).with(match(/X-VCAP-Request-ID"=>"[[:alnum:]-]+/))
        expect(fake_logger).to have_received(:debug).with(match(/X-Broker-API-Request-Identity"=>"[[:alnum:]-]+/))
        expect(fake_logger).to have_received(:debug).with(match(/X-Broker-Api-Version"=>"2\.15/))
        expect(fake_logger).to have_received(:debug).with(match(%r{X-Api-Info-Location"=>"api2\.vcap\.me/v2/info}))
      end

      context 'when an https URL is used' do
        let(:url) { 'https://broker.example.com' }
        let(:full_url) { "https://broker.example.com#{path}" }

        it 'uses SSL' do
          make_request
          expect(a_request(http_method, 'https://broker.example.com/the/path').
            with(basic_auth: ['me', 'abc123']).
            with(query: hash_including({}))).
            to have_been_made
        end

        describe 'ssl cert verification' do
          let(:http_client) do
            double(:http_client,
              :connect_timeout= => nil,
              :receive_timeout= => nil,
              :send_timeout= => nil,
              :set_auth => nil,
              :default_header= => nil,
              :default_header => {},
              :ssl_config => ssl_config,
              :request => response)
          end

          let(:response) { double(:response, code: nil, reason: nil, body: {}.to_json, headers: nil) }
          let(:ssl_config) { double(:ssl_config, :verify_mode= => nil) }

          before do
            TestConfig.override(config)
            allow(HTTPClient).to receive(:new).and_return(http_client)
            allow(http_client).to receive(http_method)
            allow(ssl_config).to receive(:set_default_paths)
          end

          context 'and the skip_cert_verify is set to true' do
            let(:config) { { skip_cert_verify: true } }

            it 'accepts self-signed cert from the broker' do
              make_request

              expect(http_client).to have_received(:ssl_config).exactly(2).times
              expect(ssl_config).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
            end
          end

          context 'and the skip_cert_verify is set to false' do
            let(:config) { { skip_cert_verify: false } }

            it 'does not accept self-signed cert from the broker' do
              make_request

              expect(http_client).to have_received(:ssl_config).exactly(2).times
              expect(ssl_config).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
            end
          end
        end
      end

      context 'X-Broker-Api-Originating-Identity' do
        context 'when user guid is set in the SecurityContext' do
          before do
            allow(VCAP::CloudController::SecurityContext).to receive(:current_user_guid).and_return('some-user-id')
          end

          it 'sets the X-Broker-API-Originating-Identity' do
            make_request
            expected_header = Base64.strict_encode64('{"user_id":"some-user-id"}')

            expect(a_request(http_method, full_url).
              with(basic_auth: basic_auth).
              with(query: hash_including({})).
              with(headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{expected_header}" })).
              to have_been_made
          end
        end

        context 'when user guid is specified as a parameter' do
          let(:user_guid) { Sham.guid }

          it 'sets the X-Broker-API-Originating-Identity' do
            make_request
            expected_header = Base64.strict_encode64("{\"user_id\":\"#{user_guid}\"}")

            expect(a_request(http_method, full_url).
              with(basic_auth: basic_auth).
              with(query: hash_including({})).
              with(headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{expected_header}" })).
              to have_been_made
          end
        end

        context 'when user guid is not provided' do
          it 'does not set the X-Broker-Api-Originating-Identity' do
            make_request
            no_user_guid = ->(request) {
              expect(request.headers).not_to have_key(VCAP::Request::HEADER_BROKER_API_ORIGINATING_IDENTITY)
              true
            }

            expect(a_request(http_method, full_url).
              with(basic_auth: basic_auth).
              with(query: hash_including({})).
              with(&no_user_guid)).to have_been_made
          end
        end

        context 'when user guid is specified as a parameter and in SecurityContext' do
          let(:user_guid) { Sham.guid }

          before do
            allow(VCAP::CloudController::SecurityContext).to receive(:current_user_guid).and_return(Sham.guid)
          end

          it 'sets the X-Broker-API-Originating-Identity from the parameter' do
            make_request
            expected_header = Base64.strict_encode64("{\"user_id\":\"#{user_guid}\"}")

            expect(a_request(http_method, full_url).
              with(basic_auth: basic_auth).
              with(query: hash_including({})).
              with(headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{expected_header}" })).
              to have_been_made
          end
        end
      end

      context 'X-Broker-API-Request-Identity' do
        it 'sets the X-Broker-API-Request-Identity header with a uuid' do
          make_request

          expect(a_request(http_method, full_url).
            with(basic_auth: basic_auth).
            with(query: hash_including({})).
            with(headers: { 'X-Broker-API-Request-Identity' => /[[:alnum:]-]+/ })).
            to have_been_made
        end
      end
    end

    shared_examples 'broker communication errors' do
      context 'when the API is not reachable' do
        context 'because the host could not be resolved' do
          before do
            stub_request(http_method, full_url).to_raise(SocketError)
          end

          it 'raises an unreachable error' do
            expect { request }.
              to raise_error(Errors::ServiceBrokerApiUnreachable)
          end
        end

        context 'because the server refused our connection' do
          before do
            stub_request(http_method, full_url).to_raise(Errno::ECONNREFUSED)
          end

          it 'raises an unreachable error' do
            expect { request }.
              to raise_error(Errors::ServiceBrokerApiUnreachable)
          end
        end
      end

      context 'when the API times out' do
        context 'because the client gave up' do
          before do
            stub_request(http_method, full_url).to_raise(HTTPClient::TimeoutError)
          end

          it 'raises a timeout error' do
            expect { request }.
              to raise_error(Errors::HttpClientTimeout)
          end
        end
      end
    end

    shared_examples 'timeout behavior' do
      before do
        TestConfig.override(config)
        allow(HTTPClient).to receive(:new).and_return(http_client)
        allow(http_client).to receive(http_method)
      end

      let(:http_client) do
        double(:http_client,
          :connect_timeout= => nil,
          :receive_timeout= => nil,
          :send_timeout= => nil,
          :set_auth => nil,
          :default_header= => nil,
          :default_header => {},
          :ssl_config => ssl_config,
          :request => response)
      end

      let(:response) { double(:response, code: 200, reason: 'OK', body: {}.to_json, headers: {}) }
      let(:ssl_config) { double(:ssl_config, :verify_mode= => nil) }

      def expect_timeout_to_be(timeout)
        expect(http_client).to have_received(:connect_timeout=).with(timeout)
        expect(http_client).to have_received(:receive_timeout=).with(timeout)
        expect(http_client).to have_received(:send_timeout=).with(timeout)
      end

      context 'when the broker client timeout is set' do
        let(:config) { { broker_client_timeout_seconds: 100 } }

        before do
          allow(http_client).to receive(http_method)
          allow(ssl_config).to receive(:set_default_paths)
        end

        it 'sets HTTP timeouts on request' do
          request
          expect_timeout_to_be 100
        end
      end
    end

    shared_examples 'logging' do
      let(:fake_logger) { instance_double(Steno::Logger, debug: nil) }
      let(:response_body) { { syslog_drain_url: 'example.com/1234', credentials: { secrets: '1234' } }.to_json }

      it 'redacts credentials from response body' do
        make_request
        expect(fake_logger).to have_received(:debug).with(/"credentials"=>"\[REDACTED\]"/)
      end

      it 'does not redact other keys' do
        make_request
        expect(fake_logger).to have_received(:debug).with(%r{"syslog_drain_url"=>"example.com/1234"})
      end

      context 'non-json responses' do
        let(:response_body) { '<xml></xml>' }

        it 'does not blow up when parsing' do
          response = make_request
          expect(response.code).to eq(200)
          expect(fake_logger).to have_received(:debug).with(/Error parsing body/)
        end
      end
    end

    shared_examples 'client that maps status codes to status code messages' do
      before do
        expect(HttpResponse).to receive(:from_http_client_response).and_call_original
        stub_request(http_method, full_url).
          with(basic_auth: basic_auth).
          to_return(status: 234, body: {}.to_json)
      end

      it 'should delegate to HttpResponse and just pass proper attrs' do
        expect(request.code).to eql(234)
        expect(request.body).to eql({}.to_json)
      end
    end

    shared_examples 'client that follows redirects' do
      let(:another_url) { "http://another-broker.example.com#{path}" }

      before do
        stub_request(http_method, full_url).
          with(basic_auth: basic_auth).
          to_return(status: 301, body: {}.to_json, headers: { Location: another_url })

        stub_request(http_method, another_url).
          with(basic_auth: basic_auth).
          to_return(status: 200, body: '')
      end

      it 'should follow redirects' do
        request

        expect(a_request(http_method, another_url)).to have_been_made
      end
    end

    describe '#get' do
      let(:http_method) { :get }

      describe 'http request' do
        let(:user_guid) { nil }
        let(:make_request) { client.get(path, user_guid: user_guid) }
        let(:response_body) { {}.to_json }

        before do
          stub_request(:get, full_url).
            with(basic_auth: basic_auth).
            to_return(status: 200, body: response_body)
        end

        it 'makes the correct GET http request' do
          make_request
          expect(a_request(:get, 'http://broker.example.com/the/path').with(basic_auth: basic_auth)).to have_been_made
        end

        it 'does not set a Content-Type header' do
          make_request
          no_content_type = ->(request) {
            expect(request.headers).not_to have_key('Content-Type')
            true
          }

          expect(a_request(:get, full_url).
            with(basic_auth: basic_auth).
            with(&no_content_type)).to have_been_made
        end

        it 'does not have a content body' do
          make_request
          expect(a_request(:get, full_url).
            with(basic_auth: basic_auth).

            with { |req| expect(req.body).to be_empty }).
            to have_been_made
        end

        it_behaves_like 'a basic successful request'

        it_behaves_like 'logging'
      end

      describe 'handling errors' do
        include_examples 'broker communication errors' do
          let(:request) { client.get(path) }
        end
      end

      it_behaves_like 'timeout behavior' do
        let(:request) { client.get(path) }
      end

      it_behaves_like 'client that maps status codes to status code messages' do
        let(:request) { client.get(path) }
      end

      it_behaves_like 'client that follows redirects' do
        let(:request) { client.get(path) }
      end
    end

    describe '#put' do
      let(:fake_logger) { instance_double(Steno::Logger, debug: nil) }
      let(:http_method) { :put }
      let(:message) do
        {
          key1: 'value1',
          key2: 'value2'
        }
      end

      describe 'http request' do
        let(:user_guid) { nil }
        let(:make_request) { client.put(path, message, user_guid: user_guid) }
        let(:response_body) { {}.to_json }

        before do
          stub_request(:put, full_url).to_return(status: 200, body: response_body)
        end

        it 'makes the correct PUT http request' do
          make_request
          expect(a_request(:put, 'http://broker.example.com/the/path').with(basic_auth: basic_auth)).to have_been_made
        end

        it 'sets the Content-Type header to application/json' do
          make_request
          expect(a_request(:put, full_url).
            with(headers: { 'Content-Type' => 'application/json' })).
            to have_been_made
        end

        it 'logs the Content-Type Header' do
          make_request
          expect(fake_logger).to have_received(:debug).with(match(%r{"Content-Type"=>"application/json"}))
        end

        it 'has a content body' do
          make_request
          expect(a_request(:put, full_url).
            with(basic_auth: basic_auth).
            with(body: {
              'key1' => 'value1',
              'key2' => 'value2'
            }.to_json)).
            to have_been_made
        end

        it_behaves_like 'logging'

        it_behaves_like 'a basic successful request'
      end

      describe 'handling errors' do
        include_examples 'broker communication errors' do
          let(:request) { client.put(path, message) }
        end
      end

      it_behaves_like 'timeout behavior' do
        let(:request) { client.put(path, message) }
        let(:ssl_config) { double(:ssl_config, :verify_mode= => nil) }

        before do
          allow(HTTPClient).to receive(:new).and_return(http_client)
          allow(http_client).to receive(http_method)
          allow(ssl_config).to receive(:set_default_paths)
        end
      end

      it_behaves_like 'client that maps status codes to status code messages' do
        let(:request) { client.put(path, message) }
      end
    end

    describe '#patch' do
      let(:fake_logger) { instance_double(Steno::Logger, debug: nil) }
      let(:http_method) { :patch }
      let(:message) do
        {
          key1: 'value1',
          key2: 'value2'
        }
      end

      describe 'http request' do
        let(:user_guid) { nil }
        let(:make_request) { client.patch(path, message, user_guid: user_guid) }
        let(:response_body) { {}.to_json }

        before do
          stub_request(:patch, full_url).
            with(basic_auth: basic_auth).
            to_return(status: 200, body: response_body)
        end

        it 'makes the correct PATCH http request' do
          make_request
          expect(a_request(:patch, 'http://broker.example.com/the/path').with(basic_auth: basic_auth)).to have_been_made
        end

        it 'sets the Content-Type header to application/json' do
          make_request
          expect(a_request(:patch, full_url).
            with(basic_auth: basic_auth).
            with(headers: { 'Content-Type' => 'application/json' })).
            to have_been_made
        end

        it 'logs the Content-Type Header' do
          make_request
          expect(fake_logger).to have_received(:debug).with(match(%r{"Content-Type"=>"application/json"}))
        end

        it 'has a content body' do
          make_request
          expect(a_request(:patch, full_url).
            with(basic_auth: basic_auth).
            with(body: {
              'key1' => 'value1',
              'key2' => 'value2'
            }.to_json)).
            to have_been_made
        end

        it_behaves_like 'a basic successful request'

        it_behaves_like 'logging'
      end

      describe 'handling errors' do
        include_examples 'broker communication errors' do
          let(:request) { client.patch(path, message) }
        end
      end

      it_behaves_like 'timeout behavior' do
        let(:request) { client.patch(path, message) }
      end

      it_behaves_like 'client that maps status codes to status code messages' do
        let(:request) { client.patch(path, message) }
      end
    end

    describe '#delete' do
      let(:http_method) { :delete }
      let(:message) do
        {
          key1: 'value1',
          key2: 'value2'
        }
      end

      describe 'http request' do
        let(:user_guid) { nil }
        let(:make_request) { client.delete(path, message, user_guid: user_guid) }
        let(:response_body) { {}.to_json }

        before do
          stub_request(:delete, full_url).
            with(basic_auth: basic_auth).with(query: message).to_return(status: 200, body: response_body)
        end

        it 'makes the correct DELETE http request' do
          make_request
          expect(a_request(:delete, 'http://broker.example.com/the/path?key1=value1&key2=value2').with(basic_auth: basic_auth)).to have_been_made
        end

        it 'does not set a Content-Type header' do
          make_request
          no_content_type = ->(request) {
            expect(request.headers).not_to have_key('Content-Type')
            true
          }

          expect(a_request(:delete, full_url).
            with(basic_auth: basic_auth).with(query: message, &no_content_type)).to have_been_made
        end

        it 'does not have a content body' do
          make_request
          expect(a_request(:delete, full_url).
            with(basic_auth: basic_auth).
            with(query: message).
            with { |req| expect(req.body).to be_empty }).
            to have_been_made
        end

        it_behaves_like 'a basic successful request'

        it_behaves_like 'logging'
      end

      describe 'handling errors' do
        include_examples 'broker communication errors' do
          let(:full_url) { "http://broker.example.com#{path}?#{message.to_query}" }
          let(:request) { client.delete(path, message) }
        end
      end

      it_behaves_like 'timeout behavior' do
        let(:request) { client.delete(path, message) }
      end

      it_behaves_like 'client that maps status codes to status code messages' do
        let(:full_url) { "http://broker.example.com#{path}?#{message.to_query}" }
        let(:request) { client.delete(path, message) }
      end
    end
  end
end
