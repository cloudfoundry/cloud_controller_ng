require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SidecarModel do
    let(:sidecar) { SidecarModel.make }

    describe '#process_types' do
      it 'returns the names of associated sidecar_process_types' do
        SidecarProcessTypeModel.make(type: 'web', sidecar: sidecar)
        SidecarProcessTypeModel.make(type: 'other worker', sidecar: sidecar)

        expect(sidecar.process_types).to eq ['web', 'other worker'].sort
      end
    end

    describe 'validations' do
      let(:app_model) { AppModel.make }
      let!(:sidecar) { SidecarModel.make(name: 'my_sidecar', app: app_model) }

      it 'validates unique sidecar name per app' do
        expect { SidecarModel.create(app: app_model, name: 'my_sidecar', command: 'some-command') }.
          to raise_error(Sequel::ValidationFailed, /Sidecar with name 'my_sidecar' already exists for given app/)
      end
    end

    describe '#to_hash' do
      let(:sidecar) { SidecarModel.make(name: 'sleepy', command: 'sleep forever') }
      let!(:worker_process_type) { SidecarProcessTypeModel.make(sidecar: sidecar, type: 'web') }
      let!(:web_process_type) { SidecarProcessTypeModel.make(sidecar: sidecar, type: 'worker') }

      it 'returns a hash of attributes' do
        expect(sidecar.to_hash).to eq({
                                        name: 'sleepy',
                                        command: 'sleep forever',
                                        types: %w[web worker]
                                      })
      end
    end

    describe 'sidecar_process_types: #around_save' do
      let(:sidecar) { SidecarModel.make }
      let(:app) { AppModel.make }

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
