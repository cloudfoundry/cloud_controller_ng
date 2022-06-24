require 'spec_helper'

RSpec.describe 'max log_quota policies' do
  let(:org_or_space) { double(:org_or_space, has_remaining_log_quota: false) }
  let(:error_name) { :random_log_quota_error }

  describe AppMaxLogQuotaPolicy do
    subject(:validator) { AppMaxLogQuotaPolicy.new(process, org_or_space, error_name) }

    context 'when the app specifies a log quota' do
      let(:process) { VCAP::CloudController::ProcessModelFactory.make(log_quota: 100, state: 'STARTED') }
      
      context 'when performing a scaling operation' do
        before do
          process.log_quota = 150
        end

        it 'registers error when quota is exceeded' do
          allow(org_or_space).to receive(:has_remaining_log_quota).with(50).and_return(false)
          expect(validator).to validate_with_error(process, :log_quota, error_name)
        end

        it 'does not register error when quota is not exceeded' do
          allow(org_or_space).to receive(:has_remaining_log_quota).with(50).and_return(true)
          expect(validator).to validate_without_error(process)
        end

        it 'adds the given error to the model' do
          allow(org_or_space).to receive(:has_remaining_log_quota).with(50).and_return(false)
          validator.validate
          expect(process.errors.on(:log_quota)).to include(error_name)
        end
      end

      context 'when not performing a scaling operation' do
        it 'does not register error' do
          process.state = 'STOPPED'
          expect(validator).to validate_without_error(process)
        end
      end
    end

    context 'when the app does not specify a log quota' do
      let(:process) { VCAP::CloudController::ProcessModelFactory.make(log_quota: -1, state: 'STARTED') }
      before do
        allow(org_or_space).to receive(:has_remaining_log_quota).and_return(true)
      end

      context 'when the org or space specifies a log quota' do
        before do
          allow(org_or_space).to receive(:log_limit).and_return(5000)
        end

        it 'is unhappy and adds an error' do
          validator.validate
          expect(process.errors.on(:log_quota)).to include(:app_requires_log_quota_to_be_specified)
        end
      end

      context 'when both the space and the org specify an infinite log quota' do
        before do
          allow(org_or_space).to receive(:log_limit).and_return(VCAP::CloudController::QuotaDefinition::UNLIMITED)
        end

        it 'is happy' do
          expect(validator).to validate_without_error(process)
        end
      end
    end
  end

  describe TaskMaxLogQuotaPolicy do
    subject(:validator) { TaskMaxLogQuotaPolicy.new(task, org_or_space, error_name) }

    let(:task) { VCAP::CloudController::TaskModel.make log_quota: 150, state: VCAP::CloudController::TaskModel::RUNNING_STATE }

    context 'when not cancelling a task' do
      it 'registers error when quota is exceeded' do
        allow(org_or_space).to receive(:has_remaining_log_quota).with(150).and_return(false)
        expect(validator).to validate_with_error(task, :log_quota, error_name)
      end

      it 'does not register error when quota is not exceeded' do
        allow(org_or_space).to receive(:has_remaining_log_quota).with(150).and_return(true)
        expect(validator).to validate_without_error(task)
      end

      it 'adds the given error to the model' do
        allow(org_or_space).to receive(:has_remaining_log_quota).with(150).and_return(false)
        validator.validate
        expect(task.errors.on(:log_quota)).to include(error_name)
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
