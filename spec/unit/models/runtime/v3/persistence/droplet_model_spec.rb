# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  describe DropletModel do
    it { is_expected.to validates_includes DropletModel::DROPLET_STATES, :state, allow_missing: true }
  end

  describe '.user_visible' do
    let(:app_model) { AppModel.make(space_guid: space.guid) }
    let!(:droplet_model) { DropletModel.make(app_guid: app_model.guid) }
    let(:space) { Space.make }

    it 'shows the developer droplets' do
      developer = User.make
      space.organization.add_user developer
      space.add_developer developer
      expect(DropletModel.user_visible(developer)).to include(droplet_model)
      expect(DropletModel.user_visible(developer).first.guid).to eq(droplet_model.guid)
    end

    it 'shows the space manager droplets' do
      space_manager = User.make
      space.organization.add_user space_manager
      space.add_manager space_manager

      expect(DropletModel.user_visible(space_manager)).to include(droplet_model)
    end

    it 'shows the auditor droplets' do
      auditor = User.make
      space.organization.add_user auditor
      space.add_auditor auditor

      expect(DropletModel.user_visible(auditor)).to include(droplet_model)
    end

    it 'shows the org manager droplets' do
      org_manager = User.make
      space.organization.add_manager org_manager

      expect(DropletModel.user_visible(org_manager)).to include(droplet_model)
    end

    it 'hides everything from a regular user' do
      evil_hacker = User.make
      expect(DropletModel.user_visible(evil_hacker)).to_not include(droplet_model)
    end
  end

  describe '#blobstore_key' do
    let(:droplet) { DropletModel.make(droplet_hash: droplet_hash) }

    context 'when the droplet has been uploaded' do
      let(:droplet_hash) { 'foobar' }

      it 'returns the correct blobstore key' do
        expect(droplet.blobstore_key).to eq(File.join(droplet.guid, droplet_hash))
      end
    end

    context 'when the droplet has not been uploaded' do
      let(:droplet_hash) { nil }

      it 'returns nil' do
        expect(droplet.blobstore_key).to be_nil
      end
    end
  end
end
