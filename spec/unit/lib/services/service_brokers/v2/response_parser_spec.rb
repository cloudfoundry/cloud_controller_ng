require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      describe ResponseParser do
        let(:url) { 'my.service-broker.com' }
        subject(:parser) { ResponseParser.new(url) }

        let(:logger) { instance_double(Steno::Logger, warn: nil) }
        before do
          allow(Steno).to receive(:logger).and_return(logger)
        end

        describe '#parse' do
          let(:response) { VCAP::Services::ServiceBrokers::V2::HttpResponse.new(body: body, code: code, message: message) }
          let(:body) { '{"foo": "bar", "state": "succeeded"}' }
          let(:code) { 200 }
          let(:message) { 'OK' }

          it 'returns the response body hash' do
            response_hash = parser.parse(:get, '/v2/catalog', response)
            expect(response_hash).to eq({ 'foo' => 'bar', 'state' => 'succeeded' })
          end

          context 'when the status code is 204' do
            let(:code) { 204 }
            let(:message) { 'No Content' }
            it 'returns a nil response' do
              response_hash = parser.parse(:get, '/v2/catalog', response)
              expect(response_hash).to be_nil
            end
          end

          context 'when the body cannot be json parsed' do
            let(:body) { '{ "not json" }' }

            before do
              allow(response).to receive(:message).and_return('OK')
            end

            it 'raises a MalformedResponse error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              expect(logger).to have_received(:warn).with(/MultiJson parse error/)
            end
          end

          context 'when the body is JSON, but not a hash' do
            let(:body) { '["just", "a", "list"]' }

            before do
              allow(response).to receive(:message).and_return('OK')
            end

            it 'raises a MalformedResponse error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              expect(logger).not_to have_received(:warn)
            end
          end

          context 'when the body is an array with empty hash' do
            let(:body) { '[{}]' }

            before do
              allow(response).to receive(:message).and_return('OK')
            end

            it 'raises a MalformedResponse error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error do |error|
                expect(error).to be_a Errors::ServiceBrokerResponseMalformed
                expect(error.to_h['source']).to eq('[{}]')
              end
            end
          end

          context 'when the status code is HTTP Unauthorized (401)' do
            let(:code) { 401 }
            let(:message) { 'Unauthorized' }
            it 'raises a ServiceBrokerApiAuthenticationFailed error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
            end
          end

          context 'when the status code is HTTP Request Timeout (408)' do
            let(:code) { 408 }
            let(:message) { 'Request Timeout' }
            it 'raises a Errors::ServiceBrokerApiTimeout error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)
            end
          end

          context 'when the status code is HTTP Conflict (409)' do
            let(:code) { 409 }
            let(:message) { 'Conflict' }
            it 'raises a ServiceBrokerConflict error' do
              expect {
                parser.parse(:get, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerConflict)
            end
          end

          context 'when the status code is HTTP Gone (410)' do
            let(:code) { 410 }
            let(:message) { 'Gone' }
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
            let(:message) { 'Bad Request' }
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
            let(:message) { 'Internal Server Error' }
            let(:method) { :get }
            let(:body) { '{"description": "there was an error"}' }
            it 'raises ServiceBrokerBadResponse' do
              expect {
                parser.parse(method, '/v2/catalog', response)
              }.to raise_error(Errors::ServiceBrokerBadResponse, /there was an error/)
            end
          end
        end

        describe '#parse with different state/code values' do
          let(:response) { VCAP::Services::ServiceBrokers::V2::HttpResponse.new(body: body, code: code, message: message) }
          let(:body) { '{"foo": "bar", "state": "succeeded"}' }
          let(:code) { 201 }
          let(:message) { 'OK' }

          context 'when the code is 201' do
            let(:code) { 201 }

            context 'when the state is `succeeded`' do
              let(:body) { '{"foo": "bar", "state": "succeeded"}' }

              it 'treats the request as a successful asynchronous request' do
                response_hash = parser.parse(:put, '/v2/service_instances', response)

                expect(response_hash).to eq({ 'foo' => 'bar', 'state' => 'succeeded' })
              end
            end

            context 'when the state is `failed`' do
              let(:body) { '{"foo": "bar", "state": "failed"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'when the state is `in progress`' do
              let(:body) { '{"foo": "bar", "state": "in progress"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'when the state is not present' do
              let(:body) { '{"foo": "bar"}' }

              it 'treats the request as a successful synchronous request' do
                response_hash = parser.parse(:put, '/v2/service_instances', response)

                expect(response_hash).to eq({ 'foo' => 'bar' })
              end
            end

            context 'when the state is any other values, e.g., fake-state' do
              let(:body) { '{"foo": "bar", "state": "fake-state"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end
          end

          context 'when the code is 202' do
            let(:code) { 202 }

            context 'when the state is `succeeded`' do
              let(:body) { '{"foo": "bar", "state": "succeeded"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'when the state is `failed`' do
              let(:body) { '{"foo": "bar", "state": "failed"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'when the state is `in progress`' do
              let(:body) { '{"foo": "bar", "state": "in progress"}' }

              it 'treats the request as a successful asynchronous request' do
                response_hash = parser.parse(:put, '/v2/service_instances', response)

                expect(response_hash).to eq({ 'foo' => 'bar', 'state' => 'in progress' })
              end
            end

            context 'when the state is not present' do
              let(:body) { '{"foo": "bar"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'when the state is any other values, e.g., fake-state' do
              let(:body) { '{"foo": "bar", "state": "fake-state"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end
          end

          context 'when the code is 200' do
            let(:code) { 200 }

            context 'when state value is valid' do
              let(:body) { '{"foo": "bar", "state": "succeeded"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'when state value is nil' do
              let(:body) { '{"foo": "bar"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'when state value is not valid, e.g., fake-state' do
              let(:body) { '{"foo": "bar", "state": "fake-state"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end
          end

          context 'when the code is 4xx' do
            let(:code) { 400 }

            context 'when state value is valid' do
              let(:body) { '{"foo": "bar", "state": "succeeded"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end

            context 'when state value is nil' do
              let(:body) { '{"foo": "bar"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end

            context 'when state value is not valid, e.g., fake-state' do
              let(:body) { '{"foo": "bar", "state": "fake-state"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end
          end

          context 'when the code is 5xx' do
            let(:code) { 500 }

            context 'when state value is valid' do
              let(:body) { '{"foo": "bar", "state": "succeeded"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'when state value is nil' do
              let(:body) { '{"foo": "bar"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'when state value is not valid, e.g., fake-state' do
              let(:body) { '{"foo": "bar", "state": "fake-state"}' }

              it 'treats the response as invalid' do
                expect {
                  parser.parse(:put, '/v2/service_instances', response)
                }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end
        end
      end
    end
  end
end
