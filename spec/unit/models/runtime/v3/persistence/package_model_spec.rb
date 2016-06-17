# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PackageModel do
    describe 'validations' do
      it { is_expected.to validates_includes PackageModel::PACKAGE_STATES, :state, allow_missing: true }

      it 'cannot have docker data if it is a bits package' do
        package = PackageModel.make(type: 'bits')
        package.docker_data = PackageDockerDataModel.new
        expect(package.valid?).to eq(false)

        expect(package.errors.full_messages).to include('type cannot have docker data if type is bits')
      end
    end

    describe '.user_visible' do
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:package_model) { PackageModel.make(app_guid: app_model.guid) }
      let(:space) { Space.make }

      it 'shows the developer packages' do
        developer = User.make
        space.organization.add_user developer
        space.add_developer developer
        expect(PackageModel.user_visible(developer)).to include(package_model)
      end

      it 'shows the space manager packages' do
        space_manager = User.make
        space.organization.add_user space_manager
        space.add_manager space_manager

        expect(PackageModel.user_visible(space_manager)).to include(package_model)
      end

      it 'shows the auditor packages' do
        auditor = User.make
        space.organization.add_user auditor
        space.add_auditor auditor

        expect(PackageModel.user_visible(auditor)).to include(package_model)
      end

      it 'shows the org manager packages' do
        org_manager = User.make
        space.organization.add_manager org_manager

        expect(PackageModel.user_visible(org_manager)).to include(package_model)
      end

      it 'hides everything from a regular user' do
        evil_hacker = User.make
        expect(PackageModel.user_visible(evil_hacker)).to_not include(package_model)
      end
    end
  end
end
