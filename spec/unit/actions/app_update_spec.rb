require 'spec_helper'
require 'actions/app_update'

module VCAP::CloudController
  describe AppUpdate do
    let(:app_update) { AppUpdate }
    let(:app_model) { AppModel.make }

    describe '#update' do
      context 'when the desired_droplet does not exist' do
        let(:message) { { 'desired_droplet_guid' => 'not_a_guid' } }

        it 'raises a DropletNotFound exception' do
          expect {
            app_update.update(app_model, message)
          }.to raise_error(AppUpdate::DropletNotFound)
        end
      end

      context 'when the desired_droplet exists' do
        let(:droplet) { DropletModel.make }
        let(:droplet_guid) { droplet.guid }
        let(:message) { { 'desired_droplet_guid' => droplet_guid } }

        context 'the droplet is not associated with the app' do
          it 'raises a DropletNotFound exception' do
            expect {
              app_update.update(app_model, message)
            }.to raise_error(AppUpdate::DropletNotFound)
          end
        end

        context 'the droplet is associated with the app' do
          before do
            app_model.add_droplet_by_guid(droplet_guid)
          end

          it 'sets the desired droplet guid' do
            updated_app = app_update.update(app_model, message)

            expect(updated_app.desired_droplet_guid).to eq(droplet_guid)
          end
        end
      end

      context 'when given a new name' do
        let(:name) { 'new name' }
        let(:message) { { 'name' => name } }

        it 'updates the app name' do
          app_update.update(app_model, message)
          app_model.reload

          expect(app_model.name).to eq(name)
        end
      end

      context 'when the app is invalid' do
        let(:name) { 'new name' }
        let(:message) { { 'name' => name } }

        before do
          allow(app_model).to receive(:save).and_raise(Sequel::ValidationFailed.new('something'))
        end

        it 'raises an invalid app error' do
          expect { app_update.update(app_model, message) }.to raise_error(AppUpdate::InvalidApp)
        end
      end
    end
  end
end
