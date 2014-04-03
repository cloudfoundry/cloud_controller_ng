require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  describe ServiceBrokerBadResponse do
    let(:uri) { 'http://www.example.com/' }
    let(:response) { double(code: 500, message: 'Internal Server Error', body: response_body) }
    let(:method) { 'PUT' }

    context 'with a description in the body' do
      let(:response_body) do
        {
          'description' => 'Some error text'
        }.to_json
      end

      it 'generates the correct hash' do
        exception = described_class.new(uri, method, response)
        exception.set_backtrace(['/foo:1', '/bar:2'])

        expect(exception.to_h).to eq({
          'description' => "Service broker error: Some error text",
          'backtrace' => ['/foo:1', '/bar:2'],
          "http" => {
            "status" => 500,
            "uri" => uri,
            "method" => "PUT"
          },
          'source' => {
            'description' => 'Some error text'
          }
        })
      end

    end

    context 'without a description in the body' do
      let(:response_body) do
        {'foo' => 'bar'}.to_json
      end
      it 'generates the correct hash' do
        exception = described_class.new(uri, method, response)
        exception.set_backtrace(['/foo:1', '/bar:2'])

        expect(exception.to_h).to eq({
          'description' => "The service broker API returned an error from http://www.example.com/: 500 Internal Server Error",
          'backtrace' => ['/foo:1', '/bar:2'],
          "http" => {
            "status" => 500,
            "uri" => uri,
            "method" => "PUT"
          },
          'source' => {'foo' => 'bar'}
        })
      end

    end

  end

  describe ServiceBrokerApiUnreachable do
    let(:uri) { 'http://www.example.com/' }
    let(:error) { SocketError.new('some message') }

    before do
      error.set_backtrace(['/socketerror:1', '/backtrace:2'])
    end

    it 'generates the correct hash' do
      exception = ServiceBrokerApiUnreachable.new(uri, 'PUT', error)
      exception.set_backtrace(['/generatedexception:3', '/backtrace:4'])

      expect(exception.to_h).to eq({
        'description' => 'The service broker API could not be reached: http://www.example.com/',
        'backtrace' => ['/generatedexception:3', '/backtrace:4'],
        'http' => {
          'uri' => uri,
          'method' => 'PUT'
        },
        'source' => {
          'description' => error.message,
          'backtrace' => ['/socketerror:1', '/backtrace:2']
        }
      })
    end
  end

  describe 'the remaining ServiceBrokers::V2 exceptions' do
    let(:uri) { 'http://uri.example.com' }
    let(:method) { 'POST' }
    let(:error) { StandardError.new }

    describe ServiceBrokerApiTimeout do
      it "initializes the base class correctly" do
        exception = ServiceBrokerApiTimeout.new(uri, method, error)
        expect(exception.message).to eq("The service broker API timed out: #{uri}")
        expect(exception.uri).to eq(uri)
        expect(exception.method).to eq(method)
        expect(exception.source).to be(error)
      end
    end

    describe ServiceBrokerResponseMalformed do
      let(:response_body) { 'foo' }
      let(:response) { double(code: 200, reason: 'OK', body: response_body) }

      it "initializes the base class correctly" do
        exception = ServiceBrokerResponseMalformed.new(uri, method, response)
        expect(exception.message).to eq("The service broker response was not understood")
        expect(exception.uri).to eq(uri)
        expect(exception.method).to eq(method)
        expect(exception.source).to be(response.body)
      end
    end

    describe ServiceBrokerApiAuthenticationFailed do
      let(:response_body) { 'foo' }
      let(:response) { double(code: 401, reason: 'Auth Error', body: response_body) }

      it "initializes the base class correctly" do
        exception = ServiceBrokerApiAuthenticationFailed.new(uri, method, response)
        expect(exception.message).to eq("Authentication failed for the service broker API. Double-check that the username and password are correct: #{uri}")
        expect(exception.uri).to eq(uri)
        expect(exception.method).to eq(method)
        expect(exception.source).to be(response.body)
      end
    end

    describe ServiceBrokerConflict do
      let(:response_body) { '{"description": "error message"}' }
      let(:response) { double(code: 409, reason: 'Conflict', body: response_body) }

      it "initializes the base class correctly" do
        exception = ServiceBrokerConflict.new(uri, method, response)
        #expect(exception.message).to eq("Resource conflict: #{uri}")
        expect(exception.message).to eq("error message")
        expect(exception.uri).to eq(uri)
        expect(exception.method).to eq(method)
        expect(exception.source).to eq(Yajl::Parser.parse(response.body))
      end

      it "has a response_code of 409" do
        exception = ServiceBrokerConflict.new(uri, method, response)
        expect(exception.response_code).to eq(409)
      end

      context "when the description field is missing" do
        let(:response_body) { '{"field": "value"}' }

        it "initializes the base class correctly" do
          exception = ServiceBrokerConflict.new(uri, method, response)
          expect(exception.message).to eq("Resource conflict: #{uri}")
          expect(exception.uri).to eq(uri)
          expect(exception.method).to eq(method)
          expect(exception.source).to eq(Yajl::Parser.parse(response.body))
        end
      end

      context "when the body is not JSON-parsable" do
        let(:response_body) { 'foo' }

        it "initializes the base class correctly" do
          exception = ServiceBrokerConflict.new(uri, method, response)
          expect(exception.message).to eq("Resource conflict: #{uri}")
          expect(exception.uri).to eq(uri)
          expect(exception.method).to eq(method)
          expect(exception.source).to eq(response.body)
        end
      end
    end
  end

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
      VCAP::Request.stub(:current_id).and_return(request_id)
    end

    shared_examples 'a basic successful request' do
      describe 'returning a correct response object' do
        subject { make_request }

        its(:code) { should eq('200') }
        its(:body) { should_not be_nil }
      end

      it 'sets X-Broker-Api-Version header correctly' do
        make_request
        a_request(http_method, full_url).
          with(:query => hash_including({})).
          with(:headers => {'X-Broker-Api-Version' => '2.2'}).
          should have_been_made
      end

      it 'sets the X-Vcap-Request-Id header to the current request id' do
        make_request
        a_request(http_method, full_url).
          with(:query => hash_including({})).
          with(:headers => { 'X-Vcap-Request-Id' => request_id }).
          should have_been_made
      end

      it 'sets the Accept header to application/json' do
        make_request
        a_request(http_method, full_url).
          with(:query => hash_including({})).
          with(:headers => { 'Accept' => 'application/json' }).
          should have_been_made
      end

      context 'when an https URL is used' do
        let(:url) { "https://broker.example.com" }
        let(:full_url) { "https://#{auth_username}:#{auth_password}@broker.example.com#{path}" }

        it 'uses SSL' do
          make_request
          a_request(http_method, 'https://me:abc123@broker.example.com/the/path').
            with(query: hash_including({})).
            should have_been_made
        end

        describe 'ssl cert verification' do
          let(:response) { double(code: nil, body: nil, to_hash: nil)}

          before do
            allow(VCAP::CloudController::Config).to receive(:config).and_return(config)
          end

          context 'and the skip_cert_verify is set to true' do
            let(:config) { {skip_cert_verify: true } }

            it 'accepts self-signed cert from the broker' do
              Net::HTTP.should_receive(:start) do |host, port, opts, &blk|
                expect(host).to eq 'broker.example.com'
                expect(port).to eq 443
                expect(opts).to eq({use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE})
              end.and_return(response)
              make_request
            end
          end

          context 'and the skip_cert_verify is set to false' do
            let(:config) { {skip_cert_verify: false } }

            it 'does not accept self-signed cert from the broker' do
              Net::HTTP.should_receive(:start) do |host, port, opts, &blk|
                expect(host).to eq 'broker.example.com'
                expect(port).to eq 443
                expect(opts).to eq({use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_PEER})
              end.and_return(response)
              make_request
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
              to raise_error(ServiceBrokerApiUnreachable)
          end
        end

        context 'because the server refused our connection' do
          before do
            stub_request(http_method, full_url).to_raise(Errno::ECONNREFUSED)
          end

          it 'raises an unreachable error' do
            expect { request }.
              to raise_error(ServiceBrokerApiUnreachable)
          end
        end
      end

      context 'when the API times out' do
        context 'because the client gave up' do
          before do
            stub_request(http_method, full_url).to_raise(Timeout::Error)
          end

          it 'raises a timeout error' do
            expect { request }.
              to raise_error(ServiceBrokerApiTimeout)
          end
        end
      end
    end

    shared_examples 'timeout behavior' do
      before do
        allow(VCAP::CloudController::Config).to receive(:config).and_return(config)
        allow(Net::HTTP).to receive(:start).and_yield(http)
      end

      let(:http)     { double('http', request: response) }
      let(:response) { double(:response, code: 200, body: {}.to_json, to_hash: {}) }

      def expect_timeout_to_be(timeout)
        expect(http).to receive(:open_timeout=).with(timeout)
        expect(http).to receive(:read_timeout=).with(timeout)
      end

      context 'when the broker client timeout is set' do
        let(:config) { {broker_client_timeout_seconds: 100} }

        it 'sets HTTP timeouts on request' do
          expect_timeout_to_be 100
          request
        end
      end

      context 'when the broker client timeout is not set' do
        let(:config) { {missing_broker_client_timeout: nil} }

        it 'defaults to a 60 second timeout' do
          expect_timeout_to_be 60
          request
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
          a_request(:get, 'http://me:abc123@broker.example.com/the/path').should have_been_made
        end

        it 'does not set a Content-Type header' do
          make_request
          no_content_type = ->(request) {
            request.headers.should_not have_key('Content-Type')
            true
          }

          a_request(:get, full_url).with(&no_content_type).should have_been_made
        end

        it 'does not have a content body' do
          make_request
          a_request(:get, full_url).
            with { |req| req.body.should be_nil }.
            should have_been_made
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
          :key1 => 'value1',
          :key2 => 'value2'
        }
      end

      describe 'http request' do
        let(:make_request) { client.put(path, message) }

        before do
          stub_request(:put, full_url).to_return(status: 200, body: {}.to_json)
        end

        it 'makes the correct PUT http request' do
          make_request
          a_request(:put, 'http://me:abc123@broker.example.com/the/path').should have_been_made
        end

        it 'sets the Content-Type header to application/json' do
          make_request
          a_request(:put, full_url).
            with(headers: { 'Content-Type' => 'application/json' }).
            should have_been_made
        end

        it 'has a content body' do
          make_request
          a_request(:put, full_url).
            with(body: {
              'key1' => 'value1',
              'key2' => 'value2'
            }.to_json).
            should have_been_made
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

    describe '#delete' do
      let(:http_method) { :delete }
      let(:message) do
        {
          :key1 => 'value1',
          :key2 => 'value2'
        }
      end

      describe 'http request' do
        let(:make_request) { client.delete(path, message) }

        before do
          stub_request(:delete, full_url).with(query: message).to_return(status: 200, body: {}.to_json)
        end

        it 'makes the correct DELETE http request' do
          make_request
          a_request(:delete, 'http://me:abc123@broker.example.com/the/path?key1=value1&key2=value2').should have_been_made
        end

        it 'does not set a Content-Type header' do
          make_request
          no_content_type = ->(request) {
            request.headers.should_not have_key('Content-Type')
            true
          }

          a_request(:delete, full_url).with(query: message, &no_content_type).should have_been_made
        end

        it 'does not have a content body' do
          make_request
          a_request(:delete, full_url).
            with(query: message).
            with { |req| req.body.should be_nil }.
            should have_been_made
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
