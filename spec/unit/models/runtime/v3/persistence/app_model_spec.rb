# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppModel do
    let(:app_model) { AppModel.create(space: space, name: 'some-name') }
    let(:space) { Space.make }

    describe '#staging_in_progress' do
      context 'when a droplet is in staging state' do
        let!(:droplet) { DropletModel.make(app_guid: app_model.guid, state: DropletModel::STAGING_STATE) }

        it 'returns true' do
          expect(app_model.staging_in_progress?).to eq(true)
        end
      end

      context 'when a droplet is not in neither pending or staging state' do
        let!(:droplet) { DropletModel.make(app_guid: app_model.guid, state: DropletModel::STAGED_STATE) }

        it 'returns false' do
          expect(app_model.staging_in_progress?).to eq(false)
        end
      end
    end

    describe 'fields' do
      describe 'max_task_sequence_id' do
        it 'defaults to 0' do
          expect(app_model.max_task_sequence_id).to eq(1)
        end
      end
    end

    describe 'validations' do
      it { is_expected.to strip_whitespace :name }

      describe 'name' do
        let(:space_guid) { space.guid }
        let(:app) { AppModel.make }

        it 'uniqueness is case insensitive' do
          AppModel.make(name: 'lowercase', space_guid: space_guid)

          expect {
            AppModel.make(name: 'lowerCase', space_guid: space_guid)
          }.to raise_error(Sequel::ValidationFailed, 'name must be unique in space')
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
          }.to raise_error(Sequel::ValidationFailed, 'name must be unique in space')
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
      context 'the model contains buildpack_lifecycle_data' do
        before { BuildpackLifecycleDataModel.make(app: app_model) }

        it 'returns the string "buildpack" if buildpack_lifecycle_data is on the model' do
          expect(app_model.lifecycle_type).to eq('buildpack')
        end
      end

      context 'the model does not contain buildpack_lifecycle_data' do
        before do
          app_model.buildpack_lifecycle_data = nil
          app_model.save
        end

        it 'returns the string "docker" if buildpack_lifecycle data is not on the model' do
          expect(app_model.lifecycle_type).to eq('docker')
        end
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

      context 'buildpack_lifecycle_data is nil' do
        let(:non_buildpack_app_model) { AppModel.create(name: 'non-buildpack', space: space) }

        it 'returns a docker data model' do
          expect(non_buildpack_app_model.lifecycle_data).to be_a(DockerLifecycleDataModel)
        end
      end
    end
  end
end
