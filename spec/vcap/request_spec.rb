require 'spec_helper'
require 'vcap/request'
require 'securerandom'

module VCAP
  describe Request do
    describe '::HEADER_NAME' do
      it "constant is expected header name" do
        expect(Request::HEADER_NAME).to eq 'X-VCAP-Request-ID'
      end
    end

    describe '.current_id' do
      after do
        described_class.current_id = nil
      end

      let(:request_id) { SecureRandom.uuid }

      it "sets the new current_id value" do
        described_class.current_id = request_id

        expect(described_class.current_id).to eq request_id

        expect(Steno.config.context.data.fetch('request_guid')).to eq request_id
      end

      it "defaults to nil" do
        expect(described_class.current_id).to be_nil
      end

      it "deletes from steno context when set to nil" do
        described_class.current_id = nil

        expect(described_class.current_id).to be_nil

        expect(Steno.config.context.data.has_key?('request_guid')).to be_false
      end
    end
  end
end
