require 'spec_helper'

describe 'max instance memory policies' do
  let(:policy_target) { double(instance_memory_limit: 150) }
  let(:error_name) { :random_memory_error }

  describe AppMaxInstanceMemoryPolicy do
    let(:app) { VCAP::CloudController::AppFactory.make(memory: 100, state: 'STARTED') }

    subject(:validator) { AppMaxInstanceMemoryPolicy.new(app, policy_target, error_name) }

    it 'gives error when app memory exceeds instance memory limit' do
      app.memory = 200
      expect(validator).to validate_with_error(app, :memory, error_name)
    end

    it 'does not give error when app memory equals instance memory limit' do
      app.memory = 150
      expect(validator).to validate_without_error(app)
    end

    context 'if the policy target is nil' do
      let(:policy_target) { nil }
      it 'does not give an error' do
        expect(validator).to validate_without_error(app)
      end
    end

    context 'when quota definition is null' do
      let(:quota_definition) { nil }

      it 'does not give error ' do
        app.memory = 150
        expect(validator).to validate_without_error(app)
      end
    end

    context 'when instance memory limit is unlimited' do
      let(:policy_target) { double(instance_memory_limit: VCAP::CloudController::QuotaDefinition::UNLIMITED) }

      it 'does not give error' do
        app.memory = 200
        expect(validator).to validate_without_error(app)
      end
    end

    it 'does not register error when not performing a scaling operation' do
      app.memory = 200
      app.state = 'STOPPED'
      expect(validator).to validate_without_error(app)
    end
  end

  describe TaskMaxInstanceMemoryPolicy do
    let(:task) { VCAP::CloudController::TaskModel.make }

    subject(:validator) { TaskMaxInstanceMemoryPolicy.new(task, policy_target, error_name) }

    it 'gives error when task memory_in_mb exceeds instance memory limit' do
      task.memory_in_mb = 200
      expect(validator).to validate_with_error(task, :memory_in_mb, error_name)
    end

    it 'does not give error when task memory_in_mb equals instance memory limit' do
      task.memory_in_mb = 150
      expect(validator).to validate_without_error(task)
    end

    context 'if the policy target is nil' do
      let(:policy_target) { nil }
      it 'does not give an error' do
        expect(validator).to validate_without_error(task)
      end
    end

    context 'when quota definition is null' do
      let(:quota_definition) { nil }

      it 'does not give error ' do
        task.memory_in_mb = 150
        expect(validator).to validate_without_error(task)
      end
    end

    context 'when instance memory limit is unlimited' do
      let(:policy_target) { double(instance_memory_limit: VCAP::CloudController::QuotaDefinition::UNLIMITED) }

      it 'does not give error' do
        task.memory_in_mb = 200
        expect(validator).to validate_without_error(task)
      end
    end
  end
end
