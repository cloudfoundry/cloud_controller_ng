require 'spec_helper'

RSpec.describe 'max instance memory policies' do
  let(:policy_target) { double(instance_memory_limit: 150) }
  let(:error_name) { :random_memory_error }

  describe AppMaxInstanceMemoryPolicy do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(memory: 30, type: 'web', app: app_model) }

    let(:validator) { SidecarMemoryLessThanProcessMemoryPolicy.new(process, 20) }

    let!(:sidecar_1) { VCAP::CloudController::SidecarModel.make(memory: 10, app: app_model) }
    let!(:sidecar_process_type_1) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar_1, type: 'web') }

    context 'when total sidecar memory is greater than than process memory' do
      let!(:sidecar_2) { VCAP::CloudController::SidecarModel.make(memory: 10, app: app_model) }
      let!(:sidecar_process_type_2) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar_2, app_guid: app_model.guid, type: 'web') }

      let!(:sidecar_3) { VCAP::CloudController::SidecarModel.make(memory: nil, app: app_model) }
      let!(:sidecar_process_type_3) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar_3, app_guid: app_model.guid, type: 'web') }

      it 'returns false' do
        expect(validator.valid?).to eq false
      end
    end

    context 'when at least one sidecar process memory is nil' do
      let!(:sidecar_3) { VCAP::CloudController::SidecarModel.make(memory: nil, app: app_model) }
      let!(:sidecar_process_type_3) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar_3, app_guid: app_model.guid, type: 'web') }

      it 'does not error' do
        expect(validator.valid?).to eq false
      end
    end

    context 'when total sidecar memory is lesser than process memory' do
      let!(:sidecar_3) { VCAP::CloudController::SidecarModel.make(memory: nil, app: app_model) }
      let!(:sidecar_process_type_3) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar_3, app_guid: app_model.guid, type: 'web') }

      let(:validator) { SidecarMemoryLessThanProcessMemoryPolicy.new(process, 10) }

      it 'returns true' do
        expect(validator.valid?).to eq true
      end
    end

    context 'when newly added sidecar process memory is nil' do
      let(:validator) { SidecarMemoryLessThanProcessMemoryPolicy.new(process, nil) }

      it 'does not error' do
        expect(validator.valid?).to eq true
      end
    end
  end
end
