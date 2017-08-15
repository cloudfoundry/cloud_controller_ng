require 'spec_helper'

RSpec.describe MaxAppInstancesPolicy do
  let(:max_apps) { 8 }
  let(:current_org_instances) { 3 }
  let(:process) { VCAP::CloudController::ProcessModelFactory.make(instances: 1, state: 'STARTED') }
  let(:org_space) { VCAP::CloudController::Space.make organization: process.organization }
  let!(:org_process) { VCAP::CloudController::ProcessModelFactory.make(space: org_space, instances: current_org_instances, state: 'STARTED') }
  let(:quota_definition) { double(app_instance_limit: max_apps) }
  let(:error_name) { :app_instance_limit_error }

  subject(:validator) { MaxAppInstancesPolicy.new(process, process.organization, quota_definition, error_name) }

  it 'gives error when number of instances across all org apps exceeds instance limit' do
    process.instances = max_apps - current_org_instances + 1
    expect(validator).to validate_with_error(process, :app_instance_limit, error_name)
  end

  it 'does not give error when number of instances of non-stopped apps equals instance limit' do
    process.instances = max_apps - current_org_instances
    expect(validator).to validate_without_error(process)
  end

  context 'when the app is stopped' do
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(instances: 1, state: 'STOPPED') }

    it 'does not give error when number of desired instances exceeds instance limit' do
      process.instances = max_apps + 9000
      expect(validator).to validate_without_error(process)
    end
  end

  context 'when number of other stopped apps exceeds instance limit' do
    let!(:stopped_process) { VCAP::CloudController::ProcessModelFactory.make(space: org_space, instances: 11, state: 'STOPPED') }

    it 'does not give error' do
      process.instances = max_apps - current_org_instances
      expect(validator).to validate_without_error(process)
    end
  end

  context 'when quota definition is null' do
    let(:quota_definition) { nil }

    it 'does not give error ' do
      process.instances = 150
      expect(validator).to validate_without_error(process)
    end
  end

  context 'when app instance limit is -1' do
    let(:quota_definition) { double(app_instance_limit: -1) }

    it 'does not give error' do
      process.instances = 150
      expect(validator).to validate_without_error(process)
    end
  end

  it 'does not register error when not performing a scaling operation' do
    process.instances = 200
    process.state = 'STOPPED'
    expect(validator).to validate_without_error(process)
  end
end
