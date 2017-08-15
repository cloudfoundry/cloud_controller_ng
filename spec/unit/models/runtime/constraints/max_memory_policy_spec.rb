require 'spec_helper'

RSpec.describe 'max memory policies' do
  let(:org_or_space) { double(:org_or_space, has_remaining_memory: false) }
  let(:error_name) { :random_memory_error }

  describe AppMaxMemoryPolicy do
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(memory: 100, state: 'STARTED') }

    subject(:validator) { AppMaxMemoryPolicy.new(process, org_or_space, error_name) }

    context 'when performing a scaling operation' do
      before do
        process.memory = 150
      end

      it 'registers error when quota is exceeded' do
        allow(org_or_space).to receive(:has_remaining_memory).with(50).and_return(false)
        expect(validator).to validate_with_error(process, :memory, error_name)
      end

      it 'does not register error when quota is not exceeded' do
        allow(org_or_space).to receive(:has_remaining_memory).with(50).and_return(true)
        expect(validator).to validate_without_error(process)
      end

      it 'adds the given error to the model' do
        allow(org_or_space).to receive(:has_remaining_memory).with(50).and_return(false)
        validator.validate
        expect(process.errors.on(:memory)).to include(error_name)
      end
    end

    context 'when not performing a scaling operation' do
      it 'does not register error' do
        process.state = 'STOPPED'
        expect(validator).to validate_without_error(process)
      end
    end
  end

  describe TaskMaxMemoryPolicy do
    subject(:validator) { TaskMaxMemoryPolicy.new(task, org_or_space, error_name) }

    let(:task) { VCAP::CloudController::TaskModel.make memory_in_mb: 150, state: VCAP::CloudController::TaskModel::RUNNING_STATE }

    context 'when not cancelling a task' do
      it 'registers error when quota is exceeded' do
        allow(org_or_space).to receive(:has_remaining_memory).with(150).and_return(false)
        expect(validator).to validate_with_error(task, :memory_in_mb, error_name)
      end

      it 'does not register error when quota is not exceeded' do
        allow(org_or_space).to receive(:has_remaining_memory).with(150).and_return(true)
        expect(validator).to validate_without_error(task)
      end

      it 'adds the given error to the model' do
        allow(org_or_space).to receive(:has_remaining_memory).with(150).and_return(false)
        validator.validate
        expect(task.errors.on(:memory_in_mb)).to include(error_name)
      end
    end

    context 'when cancelling a task' do
      it 'does not register error' do
        task.state = VCAP::CloudController::TaskModel::CANCELING_STATE
        expect(validator).to validate_without_error(task)
      end
    end

    context 'when the task is SUCCEEDED' do
      it 'does not register error' do
        task.state = VCAP::CloudController::TaskModel::SUCCEEDED_STATE
        expect(validator).to validate_without_error(task)
      end
    end

    context 'when the task is FAILED' do
      it 'does not register error' do
        task.state = VCAP::CloudController::TaskModel::FAILED_STATE
        expect(validator).to validate_without_error(task)
      end
    end
  end
end
