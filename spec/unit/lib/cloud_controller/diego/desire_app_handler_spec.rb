require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe DesireAppHandler do
      describe '.create_or_update_app' do
        let(:recipe_builder) { instance_double(AppRecipeBuilder, build_app_lrp: desired_lrp) }
        let(:client) { instance_double(BbsAppsClient) }
        let(:desired_lrp) { double(:desired_lrp) }
        let(:process_guid) { 'the-process-guid' }
        let(:get_app_response) { nil }

        before do
          allow(client).to receive(:get_app).with('the-process-guid').and_return(get_app_response)
        end

        it 'requests app creation' do
          allow(client).to receive(:desire_app)

          described_class.create_or_update_app(process_guid, recipe_builder, client)

          expect(client).to have_received(:desire_app).with(desired_lrp)
        end

        context 'when the app already exists' do
          let(:desired_lrp_update) { double(:desired_lrp_update) }
          let(:get_app_response) { double(:response) }

          before do
            allow(recipe_builder).to receive(:build_app_lrp_update).with(get_app_response).and_return(desired_lrp_update)
            allow(client).to receive(:get_app).with('the-process-guid').and_return(get_app_response)
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
