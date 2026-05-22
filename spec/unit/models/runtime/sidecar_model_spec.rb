require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SidecarModel do
    let(:sidecar) { create(:sidecar_model) }

    describe '#process_types' do
      it 'returns the names of associated sidecar_process_types' do
        create(:sidecar_process_type_model, type: 'web', sidecar: sidecar)
        create(:sidecar_process_type_model, type: 'other worker', sidecar: sidecar)

        expect(sidecar.process_types).to eq ['web', 'other worker'].sort
      end
    end

    describe 'validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :command }
    end

    describe 'sidecar model #around_save' do
      let(:app_model) { create(:app_model) }
      let!(:sidecar) { create(:sidecar_model, app_guid: app_model.guid, name: 'sidecar1', command: 'exec') }

      it 'raises validation error on unique constraint violation for sidecar' do
        expect do
          SidecarModel.create(guid: SecureRandom.uuid, app_guid: app_model.guid, name: sidecar.name, command: 'exec')
        end.to raise_error(Sequel::ValidationFailed) { |error| expect(error.message).to include("Sidecar with name 'sidecar1' already exists for given app") }
      end

      it 'raises the original error on other unique constraint violations' do
        expect do
          SidecarModel.create(guid: sidecar.guid, app_guid: app_model.guid, name: 'sidecar2', command: 'exec')
        end.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end

    describe '#to_hash' do
      let(:sidecar) { create(:sidecar_model, name: 'sleepy', command: 'sleep forever') }
      let!(:worker_process_type) { create(:sidecar_process_type_model, sidecar: sidecar, type: 'web') }
      let!(:web_process_type) { create(:sidecar_process_type_model, sidecar: sidecar, type: 'worker') }

      it 'returns a hash of attributes' do
        expect(sidecar.to_hash).to eq({
                                        name: 'sleepy',
                                        command: 'sleep forever',
                                        types: %w[web worker]
                                      })
      end
    end

    describe 'sidecar_process_types: #around_save' do
      let(:sidecar) { create(:sidecar_model) }
      let(:app) { create(:app_model) }

      it 'raises validation error on unique constraint violation for sidecar_process_types' do
        SidecarProcessTypeModel.create(sidecar: sidecar, type: 'web', app_guid: app.guid, guid: SecureRandom.uuid)

        expect do
          SidecarProcessTypeModel.create(sidecar: sidecar, type: 'web', app_guid: app.guid, guid: SecureRandom.uuid)
        end.to raise_error(Sequel::ValidationFailed) { |error|
          expect(error.message).to include('Sidecar is already associated with process type web')
        }
      end

      it 'raises original error on other unique constraint violations' do
        same_guid = SecureRandom.uuid
        SidecarProcessTypeModel.create(sidecar: sidecar, type: 'web', app_guid: app.guid, guid: same_guid)
        expect do
          SidecarProcessTypeModel.create(sidecar: sidecar, type: 'worker', app_guid: app.guid, guid: same_guid)
        end.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end
  end
end
