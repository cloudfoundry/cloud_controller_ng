require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      RSpec.shared_examples 'a parser that handles error codes' do
        context 'when the status code is 401' do
          let(:code) { 401 }

          it 'raises a ServiceBrokerApiAuthenticationFailed' do
            expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
          end
        end

        context 'when the status code is 408' do
          let(:code) { 408 }

          it 'raises a ServiceBrokerApiTimeout' do
            expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiTimeout)
          end
        end

        context 'when the status code is a non-explicitly handled 4xx' do
          let(:code) { 499 }

          it 'raises a ServiceBrokerRequestRejected' do
            expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
          end
        end
      end
    end
  end
end
