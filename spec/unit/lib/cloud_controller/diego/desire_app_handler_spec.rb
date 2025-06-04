require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe DesireAppHandler do
      describe '.create_or_update_app' do
        let(:client) { instance_double(BbsAppsClient) }
        let(:desired_lrp) { double(:desired_lrp) }
        let(:process_guid) { 'the-process-guid' }
        let(:get_app_response) { nil }
        let(:process) { ProcessModel.new }

        before do
          allow(client).to receive(:get_app).with(process).and_return(get_app_response)
        end

        it 'requests app creation' do
          allow(client).to receive(:desire_app)
          DesireAppHandler.create_or_update_app(process, client)
          expect(client).to have_received(:desire_app).with(process)
        end

        context 'when the app already exists' do
          let(:desired_lrp_update) { double(:desired_lrp_update) }
          let(:get_app_response) { double(:response) }

          before do
            allow(client).to receive(:update_app)
            allow(client).to receive(:desire_app)
          end

          it 'updates the app' do
            DesireAppHandler.create_or_update_app(process, client)
            expect(client).to have_received(:update_app).with(process, get_app_response)
            expect(client).not_to have_received(:desire_app)
          end
        end

        context 'race condition when the Diego::ProcessesSync runs and creates a process ahead of the DesireAppHandler' do
          let(:desired_lrp_update) { double(:desired_lrp_update) }
          let(:get_app_response) { nil }

          before do
            allow(client).to receive(:update_app)
            allow(client).to receive(:desire_app).and_raise CloudController::Errors::ApiError.new_from_details('RunnerError', 'the requested resource already exists')
          end

          it 'catches the error and updates the app' do
            DesireAppHandler.create_or_update_app(process, client)
            expect(client).to have_received(:update_app)
            expect(client).to have_received(:get_app).exactly(2).times
          end
        end
      end
    end
  end
end
