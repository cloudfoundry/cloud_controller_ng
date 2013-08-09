require 'spec_helper'
require 'vcap/request'
require 'securerandom'

module VCAP
  describe Request do
    describe '::HEADER_NAME' do
      subject { Request::HEADER_NAME }

      it { should == 'X-VCAP-Request-ID' }
    end

    describe '.current_id' do
      subject { described_class.current_id }
      after { described_class.current_id = nil }

      context 'when it is set' do
        let(:request_id) { SecureRandom.uuid }
        before { described_class.current_id = request_id }

        it { should == request_id }
      end

      context "when it is not set" do
        it 'returns nil' do
          described_class.current_id.should be_nil
        end
      end
    end
  end
end
