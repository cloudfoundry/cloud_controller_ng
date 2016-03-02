require 'spec_helper'

module VCAP::CloudController
  describe TaskCreateFetcher do
    let(:fetcher) { described_class.new }
    let(:app) { AppModel.make(space_guid: space.guid) }
    let(:space) { Space.make }
    let(:org) { space.organization }

    it 'should fetch the associated app, space, org' do
      returned_app, returned_space, returned_org = fetcher.fetch(app_guid: app.guid)
      expect(returned_app).to eq(app)
      expect(returned_space).to eq(space)
      expect(returned_org).to eq(org)
    end

    context 'when a droplet_guid is specified' do
      it 'should fetch the correct process' do
        droplet = DropletModel.make(app_guid: app.guid)
        _returned_app, _returned_space, _returned_org, returned_droplet = fetcher.fetch(app_guid: app.guid, droplet_guid: droplet.guid)
        expect(returned_droplet.guid).to eq(droplet.guid)
      end

      it 'should not return the droplet if it belongs to another app' do
        droplet = DropletModel.make
        _returned_app, _returned_space, _returned_org, returned_droplet = fetcher.fetch(app_guid: app.guid, droplet_guid: droplet.guid)
        expect(returned_droplet).to be_nil
      end
    end

    context 'when app is not found' do
      it 'returns nil' do
        returned_app, returned_space, returned_org, returned_droplet = fetcher.fetch(app_guid: 'not-found')
        expect(returned_app).to be_nil
        expect(returned_space).to be_nil
        expect(returned_org).to be_nil
        expect(returned_droplet).to be_nil
      end
    end
  end
end
