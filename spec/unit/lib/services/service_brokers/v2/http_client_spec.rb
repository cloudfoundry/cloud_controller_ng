require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  describe HttpClient do
    let(:auth_username) { 'me' }
    let(:auth_password) { 'abc123' }
    let(:request_id) { Sham.guid }
    let(:plan_id) { Sham.guid }
    let(:service_id) { Sham.guid }
    let(:instance_id) { Sham.guid }
    let(:url) { 'http://broker.example.com' }
    let(:full_url) { "http://#{auth_username}:#{auth_password}@broker.example.com#{path}" }
    let(:path) { '/the/path' }

    subject(:client) do
      HttpClient.new(
        url: url,
        auth_username: auth_username,
        auth_password: auth_password
      )
    end

    before do
      allow(VCAP::Request).to receive(:current_id).and_return(request_id)
    end

    shared_examples 'a basic successful request' do
      describe 'returning a correct response object' do
        subject { make_request }

        its(:code) { should eq(200) }
        its(:body) { should_not be_nil }
      end

      it 'sets X-Broker-Api-Version header correctly' do
        make_request
        expect(a_request(http_method, full_url).
          with(query: hash_including({})).
          with(headers: { 'X-Broker-Api-Version' => '2.4' })).
          to have_been_made
      end

      it 'sets the X-Vcap-Request-Id header to the current request id' do
        make_request
        expect(a_request(http_method, full_url).
          with(query: hash_including({})).
          with(headers: { 'X-Vcap-Request-Id' => request_id })).
          to have_been_made
      end

      it 'sets the Accept header to application/json' do
        make_request
        expect(a_request(http_method, full_url).
          with(query: hash_including({})).
          with(headers: { 'Accept' => 'application/json' })).
          to have_been_made
      end

      context 'when an https URL is used' do
        let(:url) { 'https://broker.example.com' }
        let(:full_url) { "https://#{auth_username}:#{auth_password}@broker.example.com#{path}" }

        it 'uses SSL' do
          make_request
          expect(a_request(http_method, 'https://me:abc123@broker.example.com/the/path').
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
              :default_header => {},
              :ssl_config => ssl_config,
              :request => response)
          end

          let(:response) { double(:response, code: nil, body: nil, headers: nil) }
          let(:ssl_config) { double(:ssl_config, :verify_mode= => nil) }

          before do
            allow(VCAP::CloudController::Config).to receive(:config).and_return(config)
            allow(HTTPClient).to receive(:new).and_return(http_client)
            allow(http_client).to receive(http_method)
          end

          context 'and the skip_cert_verify is set to true' do
            let(:config) { { skip_cert_verify: true } }

            it 'accepts self-signed cert from the broker' do
              make_request

              expect(http_client).to have_received(:ssl_config)
              expect(ssl_config).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
            end
          end

          context 'and the skip_cert_verify is set to false' do
            let(:config) { { skip_cert_verify: false } }

            it 'does not accept self-signed cert from the broker' do
              make_request

              expect(http_client).to have_received(:ssl_config)
              expect(ssl_config).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
            end
          end
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
              to raise_error(Errors::ServiceBrokerApiTimeout)
          end
        end
      end
    end

    shared_examples 'timeout behavior' do
      before do
        allow(VCAP::CloudController::Config).to receive(:config).and_return(config)
        allow(HTTPClient).to receive(:new).and_return(http_client)
        allow(http_client).to receive(http_method)
      end

      let(:http_client) do
        double(:http_client,
          :connect_timeout= => nil,
          :receive_timeout= => nil,
          :send_timeout= => nil,
          :set_auth => nil,
          :default_header => {},
          :ssl_config => ssl_config,
          :request => response)
      end

      let(:response) { double(:response, code: 200, body: {}.to_json, headers: {}) }
      let(:ssl_config) { double(:ssl_config, :verify_mode= => nil) }

      def expect_timeout_to_be(timeout)
        expect(http_client).to have_received(:connect_timeout=).with(timeout)
        expect(http_client).to have_received(:receive_timeout=).with(timeout)
        expect(http_client).to have_received(:send_timeout=).with(timeout)
      end

      context 'when the broker client timeout is set' do
        let(:config) { { broker_client_timeout_seconds: 100 } }

        it 'sets HTTP timeouts on request' do
          request
          expect_timeout_to_be 100
        end
      end

      context 'when the broker client timeout is not set' do
        let(:config) { { missing_broker_client_timeout: nil } }

        it 'defaults to a 60 second timeout' do
          request
          expect_timeout_to_be 60
        end
      end
    end

    describe '#get' do
      let(:http_method) { :get }

      describe 'http request' do
        let(:make_request) { client.get(path) }

        before do
          stub_request(:get, full_url).to_return(status: 200, body: {}.to_json)
        end

        it 'makes the correct GET http request' do
          make_request
          expect(a_request(:get, 'http://me:abc123@broker.example.com/the/path')).to have_been_made
        end

        it 'does not set a Content-Type header' do
          make_request
          no_content_type = ->(request) {
            expect(request.headers).not_to have_key('Content-Type')
            true
          }

          expect(a_request(:get, full_url).with(&no_content_type)).to have_been_made
        end

        it 'does not have a content body' do
          make_request
          expect(a_request(:get, full_url).
            with { |req| expect(req.body).to be_empty }).
            to have_been_made
        end

        it_behaves_like 'a basic successful request'
      end

      describe 'handling errors' do
        include_examples 'broker communication errors' do
          let(:request) { client.get(path) }
        end
      end

      it_behaves_like 'timeout behavior' do
        let(:request) { client.get(path) }
      end
    end

    describe '#put' do
      let(:http_method) { :put }
      let(:message) do
        {
          key1: 'value1',
          key2: 'value2'
        }
      end

      describe 'http request' do
        let(:make_request) { client.put(path, message) }

        before do
          stub_request(:put, full_url).to_return(status: 200, body: {}.to_json)
        end

        it 'makes the correct PUT http request' do
          make_request
          expect(a_request(:put, 'http://me:abc123@broker.example.com/the/path')).to have_been_made
        end

        it 'sets the Content-Type header to application/json' do
          make_request
          expect(a_request(:put, full_url).
            with(headers: { 'Content-Type' => 'application/json' })).
            to have_been_made
        end

        it 'has a content body' do
          make_request
          expect(a_request(:put, full_url).
            with(body: {
              'key1' => 'value1',
              'key2' => 'value2'
            }.to_json)).
            to have_been_made
        end

        it_behaves_like 'a basic successful request'
      end

      describe 'handling errors' do
        include_examples 'broker communication errors' do
          let(:request) { client.put(path, message) }
        end
      end

      it_behaves_like 'timeout behavior' do
        let(:request) { client.put(path, message) }
      end
    end

    describe '#patch' do
      let(:http_method) { :patch }
      let(:message) do
        {
          key1: 'value1',
          key2: 'value2'
        }
      end

      describe 'http request' do
        let(:make_request) { client.patch(path, message) }

        before do
          stub_request(:patch, full_url).to_return(status: 200, body: {}.to_json)
        end

        it 'makes the correct PATCH http request' do
          make_request
          expect(a_request(:patch, 'http://me:abc123@broker.example.com/the/path')).to have_been_made
        end

        it 'sets the Content-Type header to application/json' do
          make_request
          expect(a_request(:patch, full_url).
            with(headers: { 'Content-Type' => 'application/json' })).
            to have_been_made
        end

        it 'has a content body' do
          make_request
          expect(a_request(:patch, full_url).
            with(body: {
            'key1' => 'value1',
            'key2' => 'value2'
          }.to_json)).
            to have_been_made
        end

        it_behaves_like 'a basic successful request'
      end

      describe 'handling errors' do
        include_examples 'broker communication errors' do
          let(:request) { client.patch(path, message) }
        end
      end

      it_behaves_like 'timeout behavior' do
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
        let(:make_request) { client.delete(path, message) }

        before do
          stub_request(:delete, full_url).with(query: message).to_return(status: 200, body: {}.to_json)
        end

        it 'makes the correct DELETE http request' do
          make_request
          expect(a_request(:delete, 'http://me:abc123@broker.example.com/the/path?key1=value1&key2=value2')).to have_been_made
        end

        it 'does not set a Content-Type header' do
          make_request
          no_content_type = ->(request) {
            expect(request.headers).not_to have_key('Content-Type')
            true
          }

          expect(a_request(:delete, full_url).with(query: message, &no_content_type)).to have_been_made
        end

        it 'does not have a content body' do
          make_request
          expect(a_request(:delete, full_url).
            with(query: message).
            with { |req| expect(req.body).to be_empty }).
            to have_been_made
        end

        it_behaves_like 'a basic successful request'
      end

      describe 'handling errors' do
        include_examples 'broker communication errors' do
          let(:full_url) { "http://#{auth_username}:#{auth_password}@broker.example.com#{path}?#{message.to_query}" }
          let(:request) { client.delete(path, message) }
        end
      end

      it_behaves_like 'timeout behavior' do
        let(:request) { client.delete(path, message) }
      end
    end
  end
end
