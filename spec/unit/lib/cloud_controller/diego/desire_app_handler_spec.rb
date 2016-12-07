require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe DesireAppHandler do
      describe '.create_or_update_app' do
        let(:recipe_builder) do
          instance_double(AppRecipeBuilder,
            build_app_lrp:        desired_lrp,
            build_app_lrp_update: desired_lrp_update,
          )
        end
        let(:client) { instance_double(BbsAppsClient) }
        let(:desired_lrp) { double(:desired_lrp) }
        let(:desired_lrp_update) { double(:desired_lrp_update) }
        let(:process_guid) { 'the-process-guid' }

        before do
          allow(client).to receive(:app_exists?).with('the-process-guid').and_return(false)
        end

        it 'requests app creation' do
          allow(client).to receive(:desire_app)

          described_class.create_or_update_app(process_guid, recipe_builder, client)

          expect(client).to have_received(:desire_app).with(desired_lrp)
        end

        context 'when the app already exists' do
          before do
            allow(client).to receive(:app_exists?).with('the-process-guid').and_return(true)
            allow(client).to receive(:update_app)
            allow(client).to receive(:desire_app)
          end

          it 'updates the app' do
            described_class.create_or_update_app(process_guid, recipe_builder, client)

            expect(client).to have_received(:update_app).with('the-process-guid', desired_lrp_update)
            expect(client).not_to have_received(:desire_app)
          end
        end
      end
    end
  end
end
