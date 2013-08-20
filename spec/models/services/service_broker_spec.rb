require 'spec_helper'

module VCAP::CloudController::Models
  describe ServiceBroker, :services, type: :model do
    let(:name) { Sham.name }
    let(:broker_url) { 'http://cf-service-broker.example.com' }
    let(:token) { 'abc123' }

    subject(:broker) { ServiceBroker.new(name: name, broker_url: broker_url, token: token) }

    before do
      reset_database
    end

    describe '#valid?' do
      it 'validates the name is present' do
        expect(broker).to be_valid
        broker.name = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:name)).to include(:presence)
      end

      it 'validates the url is present' do
        expect(broker).to be_valid
        broker.broker_url = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:broker_url)).to include(:presence)
      end

      it 'validates the token is present' do
        expect(broker).to be_valid
        broker.token = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:token)).to include(:presence)
      end

      it 'validates the name is unique' do
        expect(broker).to be_valid
        ServiceBroker.make(name: broker.name)
        expect(broker).to_not be_valid
        expect(broker.errors.on(:name)).to include(:unique)
      end

      it 'validates the url is unique' do
        expect(broker).to be_valid
        ServiceBroker.make(broker_url: broker.broker_url)
        expect(broker).to_not be_valid
        expect(broker.errors.on(:broker_url)).to include(:unique)
      end
    end

    describe '#check!' do
      let(:broker_api_url) { "http://cc:#{token}@cf-service-broker.example.com/v3" }

      before do
        stub_request(:get, broker_api_url).to_return(status: 200, body: '["OK"]')
      end

      it 'should ping the broker API' do
        broker.check!

        expect(a_request(:get, broker_api_url)).to have_been_made.once
      end

      context 'when the API is not reachable' do
        context 'because the host could not be resolved' do
          before do
            stub_request(:get, broker_api_url).to_raise(SocketError)
          end

          it 'should raise an unreachable error' do
            expect {
              broker.check!
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiUnreachable)
          end
        end

        context 'because the server connection attempt timed out' do
          before do
            stub_request(:get, broker_api_url).to_raise(HTTPClient::ConnectTimeoutError)
          end

          it 'should raise an unreachable error' do
            expect {
              broker.check!
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiUnreachable)
          end
        end

        context 'because the server refused our connection' do
          before do
            stub_request(:get, broker_api_url).to_raise(Errno::ECONNREFUSED)
          end

          it 'should raise an unreachable error' do
            expect {
              broker.check!
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiUnreachable)
          end
        end
      end

      context 'when the API times out' do
        context 'because the server gave up' do
          before do
            # We have to instantiate the error object to keep WebMock from initializing
            # it with a String message. KeepAliveDisconnected actually takes an optional
            # Session object, which later HTTPClient code attempts to use.
            stub_request(:get, broker_api_url).to_raise(HTTPClient::KeepAliveDisconnected.new)
          end

          it 'should raise a timeout error' do
            expect {
              broker.check!
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiTimeout)
          end
        end

        context 'because the client gave up' do
          before do
            stub_request(:get, broker_api_url).to_raise(HTTPClient::ReceiveTimeoutError)
          end

          it 'should raise a timeout error' do
            expect {
              broker.check!
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiTimeout)
          end
        end
      end

      context 'when the API returns an invalid response' do
        context 'because of an unexpected status code' do
          before do
            stub_request(:get, broker_api_url).to_return(status: 201, body: '["OK"]')
          end

          it 'should raise an invalid response error' do
            expect {
              broker.check!
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiInvalid)
          end
        end

        context 'because of an unexpected body' do
          before do
            stub_request(:get, broker_api_url).to_return(status: 200, body: '["BAD"]')
          end

          it 'should raise an invalid response error' do
            expect {
              broker.check!
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiInvalid)
          end
        end
      end

      context 'when the API cannot authenticate the client' do
        before do
          stub_request(:get, broker_api_url).to_return(status: 401)
        end

        it 'should raise an authentication error' do
          expect {
            broker.check!
          }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiAuthenticationFailed)
        end
      end
    end
  end
end
