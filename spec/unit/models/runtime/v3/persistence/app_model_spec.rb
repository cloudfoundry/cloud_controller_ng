# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  describe AppModel do
    let(:app_model) { AppModel.make }
    let(:space) { Space.find(guid: app_model.space_guid) }

    describe '.user_visible' do
      it 'shows the developer apps' do
        developer = User.make
        space.organization.add_user developer
        space.add_developer developer
        expect(AppModel.user_visible(developer)).to include(app_model)
      end

      it 'shows the space manager apps' do
        space_manager = User.make
        space.organization.add_user space_manager
        space.add_manager space_manager

        expect(AppModel.user_visible(space_manager)).to include(app_model)
      end

      it 'shows the auditor apps' do
        auditor = User.make
        space.organization.add_user auditor
        space.add_auditor auditor

        expect(AppModel.user_visible(auditor)).to include(app_model)
      end

      it 'shows the org manager apps' do
        org_manager = User.make
        space.organization.add_manager org_manager

        expect(AppModel.user_visible(org_manager)).to include(app_model)
      end

      it 'hides everything from a regular user' do
        evil_hacker = User.make
        expect(AppModel.user_visible(evil_hacker)).to_not include(app_model)
      end
    end

    describe 'validations' do
      describe 'name' do
        let(:space_guid) { space.guid }
        let(:app) { AppModel.make }

        it 'uniqueness is case insensitive' do
          AppModel.make(name: 'lowercase', space_guid: space_guid)

          expect {
            AppModel.make(name: 'lowerCase', space_guid: space_guid)
          }.to raise_error(Sequel::ValidationFailed, /space_guid and name/)
        end

        it 'should allow standard ascii characters' do
          app.name = "A -_- word 2!?()\'\"&+."
          expect {
            app.save
          }.to_not raise_error
        end

        it 'should allow backslash characters' do
          app.name = 'a \\ word'
          expect {
            app.save
          }.to_not raise_error
        end

        it 'should allow unicode characters' do
          app.name = '防御力¡'
          expect {
            app.save
          }.to_not raise_error
        end

        it 'should not allow newline characters' do
          app.name = "a \n word"
          expect {
            app.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow escape characters' do
          app.name = "a \e word"
          expect {
            app.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe 'name is unique within a space' do
        it 'name can be reused in different spaces' do
          name = 'zach'

          space1 = Space.make
          space2 = Space.make

          AppModel.make(name: name, space_guid: space1.guid)
          expect {
            AppModel.make(name: name, space_guid: space2.guid)
          }.not_to raise_error
        end

        it 'name is unique in the same space' do
          name = 'zach'

          space = Space.make

          AppModel.make(name: name, space_guid: space.guid)

          expect {
            AppModel.make(name: name, space_guid: space.guid)
          }.to raise_error(Sequel::ValidationFailed, /space_guid and name/)
        end
      end

      describe 'environment_variables' do
        it 'validates them' do
          expect {
            AppModel.make(environment_variables: '')
          }.to raise_error(Sequel::ValidationFailed, /must be a hash/)
        end
      end

      describe 'droplet' do
        let(:droplet) { DropletModel.make(app: app_model) }

        it 'does not allow droplets that are not STAGED' do
          states = DropletModel::DROPLET_STATES - [DropletModel::STAGED_STATE]
          states.each do |state|
            droplet.state = state
            expect {
              app_model.droplet = droplet
              app_model.save
            }.to raise_error(Sequel::ValidationFailed, /must be in staged state/)
          end
        end

        it 'is valid with droplets that are STAGED' do
          droplet.state = DropletModel::STAGED_STATE
          app_model.droplet = droplet
          expect(app_model).to be_valid
        end
      end
    end

    describe '#lifecycle_type' do
      let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(app: app_model) }

      it 'returns the string "buildpack" if buildpack_lifecycle_data is on the model' do
        expect(app_model.lifecycle_type).to eq('buildpack')
      end
    end

    describe '#lifecycle_data' do
      let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(app: app_model) }

      it 'returns buildpack_lifecycle_data if it is on the model' do
        expect(app_model.lifecycle_data).to eq(lifecycle_data)
      end

      it 'is a persistable hash' do
        expect(app_model.reload.lifecycle_data.buildpack).to eq(lifecycle_data.buildpack)
        expect(app_model.reload.lifecycle_data.stack).to eq(lifecycle_data.stack)
      end

      context 'lifecycle_data is nil' do
        let(:non_buildpack_app_model) { AppModel.make }

        it 'returns nil if no lifecycle data types are present' do
          expect(non_buildpack_app_model.lifecycle_data).to eq(nil)
        end
      end
    end
  end
end
