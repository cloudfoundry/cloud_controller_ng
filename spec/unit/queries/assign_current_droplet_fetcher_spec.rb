require 'spec_helper'
require 'queries/assign_current_droplet_fetcher'

module VCAP::CloudController
  describe AssignCurrentDropletFetcher do
    describe '#fetch' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let(:droplet) { DropletModel.make }
      let(:org) { space.organization }

      before do
        app.add_droplet(droplet)
      end

      it 'returns the desired app, space, org, and droplet' do
        returned_app, returned_space, returned_org, returned_droplet = AssignCurrentDropletFetcher.new.fetch(app.guid, droplet.guid)
        expect(returned_app).to eq(app)
        expect(returned_space).to eq(space)
        expect(returned_org).to eq(org)
        expect(returned_droplet).to eq(droplet.reload)
      end

      context 'when the app is not found' do
        it 'returns nil' do
          returned_app, returned_space, returned_org, returned_droplet = AssignCurrentDropletFetcher.new.fetch('bogus', droplet.guid)
          expect(returned_app).to be_nil
          expect(returned_space).to be_nil
          expect(returned_org).to be_nil
          expect(returned_droplet).to be_nil
        end
      end

      context 'when the app does not have the associated droplet' do
        it 'returns nil for the droplet' do
          returned_app, returned_space, returned_org, returned_droplet = AssignCurrentDropletFetcher.new.fetch(app.guid, 'bogus')
          expect(returned_app).to eq(app)
          expect(returned_space).to eq(space)
          expect(returned_org).to eq(org)
          expect(returned_droplet).to be_nil
        end
      end
    end
  end
end
