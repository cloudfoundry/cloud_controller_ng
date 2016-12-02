require 'spec_helper'

module VCAP::CloudController::Diego
  RSpec.describe BbsAppsClient do
    subject(:client) { BbsAppsClient.new(bbs_client) }

    describe '#desire_app' do
      let(:bbs_client) { instance_double(::Diego::Client, desire_lrp: lurp_response) }

      let(:lurp) { ::Diego::Bbs::Models::DesiredLRP.new }
      let(:lurp_response) { ::Diego::Bbs::Models::DesiredLRPResponse.new }

      it 'sends the lrp to diego' do
        client.desire_app(lurp)
        expect(bbs_client).to have_received(:desire_lrp).with(lurp)
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:desire_lrp).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.desire_app(lurp)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('RunnerUnavailable')
          end
        end
      end

      context 'when bbs returns a response with an error' do
        before do
          allow(bbs_client).to receive(:desire_lrp).and_return(
            ::Diego::Bbs::Models::DesiredLRPResponse.new(error: ::Diego::Bbs::Models::Error.new(message: 'error message'))
          )
        end

        it 'raises an api error' do
          expect {
            client.desire_app(lurp)
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('RunnerError')
          end
        end
      end
    end
  end
end
