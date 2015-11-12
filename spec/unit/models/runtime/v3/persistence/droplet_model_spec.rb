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

  describe '#staged?' do
    context 'when the droplet has been staged' do
      let!(:droplet_model) { DropletModel.make(state: 'STAGED') }

      it 'returns true' do
        expect(droplet_model.staged?).to be true
      end
    end

    context 'when the droplet has not been staged' do
      let!(:droplet_model) { DropletModel.make(state: 'PENDING') }

      it 'returns false' do
        expect(droplet_model.staged?).to be false
      end
    end
  end

  describe '#mark_as_staged' do
    let!(:droplet_model) { DropletModel.make }

    it 'changes the droplet state to STAGED' do
      droplet_model.mark_as_staged
      expect(droplet_model.state).to be DropletModel::STAGED_STATE
    end
  end

  describe 'process_types' do
    let(:droplet_model) { DropletModel.make }

    it 'is a persistable hash' do
      info = { web: 'started', worker: 'started' }
      droplet_model.process_types = info
      droplet_model.save
      expect(droplet_model.reload.process_types['web']).to eq('started')
      expect(droplet_model.reload.process_types['worker']).to eq('started')
    end
  end

  describe '#lifecycle_type' do
    let(:droplet_model) { DropletModel.make }
    let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(droplet: droplet_model) }

    before do
      droplet_model.buildpack_lifecycle_data = lifecycle_data
      droplet_model.save
    end

    it 'returns the string "buildpack" if buildpack_lifecycle_data is on the model' do
      expect(droplet_model.lifecycle_type).to eq('buildpack')
    end
  end

  describe '#lifecycle_data' do
    let(:droplet_model) { DropletModel.make }
    let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(droplet: droplet_model) }

    before do
      droplet_model.buildpack_lifecycle_data = lifecycle_data
      droplet_model.save
    end

    it 'returns buildpack_lifecycle_data if it is on the model' do
      expect(droplet_model.lifecycle_data).to eq(lifecycle_data)
    end

    it 'is a persistable hash' do
      expect(droplet_model.reload.lifecycle_data.buildpack).to eq(lifecycle_data.buildpack)
      expect(droplet_model.reload.lifecycle_data.stack).to eq(lifecycle_data.stack)
    end
  end
end
