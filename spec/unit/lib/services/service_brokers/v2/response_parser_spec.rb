require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      describe ResponseParser do
        let(:url) { 'my.service-broker.com' }
        subject(:parser) { ResponseParser.new(url) }

        let(:logger) { double(:logger, warn: nil) }
        before do
          allow(Steno).to receive(:logger).and_return(logger)
        end

        describe '#parse' do
          let(:response) { double(:response, body: body, code: code) }
          let(:body) { '{"foo": "bar"}' }
          let(:code) { 200 }

          it 'returns the response body hash' do
            response_hash = parser.parse(:get, '/v2/catalog', response)
            expect(response_hash).to eq({ 'foo' => 'bar' })
          end

          context 'when the status code is 204' do
            let(:code) { 204 }
            it 'returns a nil response' do
              response_hash = parser.parse(:get, '/v2/catalog', response)
              expect(response_hash).to be_nil
            end
          end

          context 'when the body cannot be json parsed' do
            let(:body) { '{ "not json" }' }

            it 'raises a MalformedResponse error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              expect(logger).to have_received(:warn).with(/MultiJson parse error/)
            end
          end

          context 'when the body is JSON, but not a hash' do
            let(:body) { '["just", "a", "list"]' }

            it 'raises a MalformedResponse error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              expect(logger).not_to have_received(:warn)
            end
          end

          context 'when the status code is HTTP Unauthorized (401)' do
            let(:code) { 401 }
            it 'raises a ServiceBrokerApiAuthenticationFailed error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
            end
          end

          context 'when the status code is HTTP Request Timeout (408)' do
            let(:code) { 408 }
            it 'raises a Errors::ServiceBrokerApiTimeout error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)
            end
          end

          context 'when the status code is HTTP Conflict (409)' do
            let(:code) { 409 }
            it 'raises a ServiceBrokerConflict error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerConflict)
            end
          end

          context 'when the status code is HTTP Gone (410)' do
            let(:code) { 410 }
            let(:method) { :get }
            let(:body) { '{"description": "there was an error"}' }
            it 'raises ServiceBrokerBadResponse' do
              expect {
                parser.parse(method, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerBadResponse, /there was an error/)
            end

            context 'and the http method is delete' do
              let(:method) { :delete }
              it 'does not raise an error and logs a warning' do
                response_hash = parser.parse(method, '/v2/catalog', response)
                expect(response_hash).to be_nil
                expect(logger).to have_received(:warn).with(/Already deleted/)
              end
            end
          end

          context 'when the status code is any other 4xx error' do
            let(:code) { 400 }
            let(:method) { :get }
            let(:body) { '{"description": "there was an error"}' }
            it 'raises ServiceBrokerRequestRejected' do
              expect {
                parser.parse(method, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerRequestRejected, /there was an error/)
            end
          end

          context 'when the status code is any 5xx error' do
            let(:code) { 500 }
            let(:method) { :get }
            let(:body) { '{"description": "there was an error"}' }
            it 'raises ServiceBrokerBadResponse' do
              expect {
                parser.parse(method, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerBadResponse, /there was an error/)
            end
          end
        end
      end
    end
  end
end
