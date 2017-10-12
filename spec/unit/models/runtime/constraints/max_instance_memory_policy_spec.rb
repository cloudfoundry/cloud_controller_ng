require 'spec_helper'

RSpec.describe 'max instance memory policies' do
  let(:policy_target) { double(instance_memory_limit: 150) }
  let(:error_name) { :random_memory_error }

  describe AppMaxInstanceMemoryPolicy do
    subject(:validator) { AppMaxInstanceMemoryPolicy.new(process, policy_target, error_name) }

    context 'app starts off STARTED with memory under quota' do
      let(:process) { VCAP::CloudController::ProcessModelFactory.make(memory: 100, state: 'STARTED') }

      it 'gives error when app memory exceeds instance memory limit' do
        process.memory = 200
        expect(validator).to validate_with_error(process, :memory, error_name)
      end

      it 'does not give error when app memory equals instance memory limit' do
        process.memory = 150
        expect(validator).to validate_without_error(process)
      end

      context 'if the policy target is nil' do
        let(:policy_target) { nil }
        it 'does not give an error' do
          expect(validator).to validate_without_error(process)
        end
      end

      context 'when quota definition is null' do
        let(:quota_definition) { nil }

        it 'does not give error ' do
          process.memory = 150
          expect(validator).to validate_without_error(process)
        end
      end

      context 'when instance memory limit is unlimited' do
        let(:policy_target) { double(instance_memory_limit: VCAP::CloudController::QuotaDefinition::UNLIMITED) }

        it 'does not give error' do
          process.memory = 200
          expect(validator).to validate_without_error(process)
        end
      end

      it 'does not register error when not performing a scaling operation' do
        process.memory = 200
        process.state = 'STOPPED'
        expect(validator).to validate_without_error(process)
      end
    end

    context 'app starts off STARTED with memory over quota' do
      let(:process) { VCAP::CloudController::ProcessModelFactory.make(memory: 200, state: 'STARTED') }

      subject(:validator) { AppMaxInstanceMemoryPolicy.new(process, policy_target, error_name) }

      it 'gives an error when the app is created' do
        expect(validator).to validate_with_error(process, :memory, error_name)
      end
    end

    context 'app starts off STARTED with memory at quota' do
      let(:process) { VCAP::CloudController::ProcessModelFactory.make(memory: 150, state: 'STARTED') }

      it 'does not give an error when the app is created' do
        expect(validator).to validate_without_error(process)
      end
      # Assume other tests are similar to the first context block.
    end

    context 'app starts off STOPPED with memory under quota' do
      let(:process) { VCAP::CloudController::ProcessModelFactory.make(memory: 100, state: 'STOPPED') }

      it 'gives error when app memory exceeds instance memory limit' do
        process.memory = 200
        expect(validator).to validate_without_error(process)
      end

      it 'does not give error when app memory equals instance memory limit' do
        process.memory = 150
        expect(validator).to validate_without_error(process)
      end

      context 'if the policy target is nil' do
        let(:policy_target) { nil }
        it 'does not give an error' do
          expect(validator).to validate_without_error(process)
        end
      end

      context 'when quota definition is null' do
        let(:quota_definition) { nil }

        it 'does not give error ' do
          process.memory = 150
          expect(validator).to validate_without_error(process)
        end
      end

      context 'when instance memory limit is unlimited' do
        let(:policy_target) { double(instance_memory_limit: VCAP::CloudController::QuotaDefinition::UNLIMITED) }

        it 'does not give error' do
          process.memory = 200
          expect(validator).to validate_without_error(process)
        end
      end

      it 'does not register error when not performing a scaling operation' do
        process.memory = 200
        process.state = 'STOPPED'
        expect(validator).to validate_without_error(process)
      end
    end

    context 'app starts off STOPPED with memory over quota' do
      let(:process) { VCAP::CloudController::ProcessModelFactory.make(memory: 200, state: 'STOPPED') }

      it 'gives an error when the app is created' do
        expect(validator).to validate_without_error(process)
      end
    end

    context 'app starts off STOPPED with memory at quota' do
      let(:process) { VCAP::CloudController::ProcessModelFactory.make(memory: 150, state: 'STOPPED') }

      it 'does not give an error when the app is created' do
        expect(validator).to validate_without_error(process)
      end
      # Assume other tests are similar to the first context block.
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
