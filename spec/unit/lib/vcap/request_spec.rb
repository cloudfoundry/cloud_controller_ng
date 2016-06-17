require 'spec_helper'
require 'vcap/request'
require 'securerandom'

module VCAP
  RSpec.describe Request do
    describe '::HEADER_NAME' do
      it 'constant is expected header name' do
        expect(Request::HEADER_NAME).to eq 'X-VCAP-Request-ID'
      end
    end

    describe '::HEADER_BROKER_API_VERSION' do
      it 'constant is expected api version' do
        expect(Request::HEADER_BROKER_API_VERSION).to eq 'X-Broker-Api-Version'
      end
    end

    describe '::HEADER_API_INFO' do
      it 'constant is expected api info' do
        expect(Request::HEADER_API_INFO_LOCATION).to eq 'X-Api-Info-Location'
      end
    end

    describe '.current_id' do
      after do
        described_class.current_id = nil
      end

      let(:request_id) { SecureRandom.uuid }
      let(:data) { {} }

      before do
        allow(Steno.config.context).to receive(:data).and_return(data)
      end

      it 'sets the new current_id value' do
        described_class.current_id = request_id

        expect(described_class.current_id).to eq request_id
        expect(Steno.config.context.data.fetch('request_guid')).to eq request_id
      end

      it 'deletes from steno context when set to nil' do
        described_class.current_id = nil

        expect(described_class.current_id).to be_nil
        expect(Steno.config.context.data.key?('request_guid')).to be false
      end

      it 'uses the :vcap_request_id thread local' do
        described_class.current_id = request_id

        expect(Thread.current[:vcap_request_id]).to eq(request_id)
      end
    end
  end
end
