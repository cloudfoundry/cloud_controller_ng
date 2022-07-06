require 'spec_helper'

RSpec.describe 'max log_rate_limit policies' do
  let(:org_or_space) { double(:org_or_space, has_remaining_log_rate_limit: false) }
  let(:error_name) { :random_log_rate_limit_error }

  describe AppMaxLogRateLimitPolicy do
    subject(:validator) { AppMaxLogRateLimitPolicy.new(process, org_or_space, error_name) }

    context 'when the app specifies a log quota' do
      let(:process) { VCAP::CloudController::ProcessModelFactory.make(log_rate_limit: 100, state: 'STOPPED') }

      context 'when performing a scaling operation' do
        before do
          process.state = 'STARTED'
          process.log_rate_limit = 150
        end

        it 'registers error when quota is exceeded' do
          expect(org_or_space).to receive(:has_remaining_log_rate_limit).with(150).and_return(false)
          expect(validator).to validate_with_error(process, :log_rate_limit, error_name)
        end

        it 'does not register error when quota is not exceeded' do
          expect(org_or_space).to receive(:has_remaining_log_rate_limit).with(150).and_return(true)
          expect(validator).to validate_without_error(process)
        end

        it 'adds the given error to the model' do
          expect(org_or_space).to receive(:has_remaining_log_rate_limit).with(150).and_return(false)
          validator.validate
          expect(process.errors.on(:log_rate_limit)).to include(error_name)
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
      let(:process) { VCAP::CloudController::ProcessModelFactory.make(log_rate_limit: -1, state: 'STOPPED') }
      before do
        process.state = 'STARTED'
      end

      context 'when the org specifies a log quota' do
        before do
          allow(org_or_space).to receive(:name).and_return('some-org')
          allow(org_or_space).to receive(:log_rate_limit).and_return(5000)
        end

        it 'is unhappy and adds an error' do
          validator.validate
          expect(process.errors.on(:log_rate_limit)).to include("cannot be unlimited in organization 'some-org'.")
        end
      end

      context 'when the space specifies a log quota' do
        before do
          allow(org_or_space).to receive(:name).and_return('some-space')
          allow(org_or_space).to receive(:log_rate_limit).and_return(5000)
          allow(org_or_space).to receive(:organization_guid).and_return('some-org-guid')
        end

        it 'is unhappy and adds an error' do
          validator.validate
          expect(process.errors.on(:log_rate_limit)).to include("cannot be unlimited in space 'some-space'.")
        end
      end

      context 'when both the space and the org specify an infinite log quota' do
        before do
          expect(org_or_space).to receive(:log_rate_limit).and_return(VCAP::CloudController::QuotaDefinition::UNLIMITED)
          expect(org_or_space).to receive(:has_remaining_log_rate_limit).and_return(true)
        end

        it 'is happy' do
          expect(validator).to validate_without_error(process)
        end
      end
    end
  end

  describe TaskMaxLogRateLimitPolicy do
    subject(:validator) { TaskMaxLogRateLimitPolicy.new(task, org_or_space, error_name) }

    let(:task) { VCAP::CloudController::TaskModel.make log_rate_limit: 150, state: VCAP::CloudController::TaskModel::RUNNING_STATE }

    context 'when not cancelling a task' do
      it 'registers error when quota is exceeded' do
        allow(org_or_space).to receive(:has_remaining_log_rate_limit).with(150).and_return(false)
        expect(validator).to validate_with_error(task, :log_rate_limit, error_name)
      end

      it 'does not register error when quota is not exceeded' do
        allow(org_or_space).to receive(:has_remaining_log_rate_limit).with(150).and_return(true)
        expect(validator).to validate_without_error(task)
      end

      it 'adds the given error to the model' do
        allow(org_or_space).to receive(:has_remaining_log_rate_limit).with(150).and_return(false)
        validator.validate
        expect(task.errors.on(:log_rate_limit)).to include(error_name)
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
