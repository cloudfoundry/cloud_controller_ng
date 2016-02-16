require 'spec_helper'

describe MaxAppTasksPolicy do
  let(:quota_definition) { VCAP::CloudController::QuotaDefinition.make(app_task_limit: 1) }
  let(:org) { space.organization }
  let(:space) { VCAP::CloudController::Space.make }
  let(:app) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
  let(:task) { VCAP::CloudController::TaskModel.new(app: app) }
  let(:error_name) { :app_task_limit_error }

  subject(:validator) { described_class.new(task, org, error_name) }

  before do
    org.quota_definition = quota_definition if org
  end

  it 'does not register error when quota is not exceeded' do
    expect(validator).to validate_without_error(task)
  end

  context 'when app task limit is null' do
    let(:quota_definition) { nil }

    it 'does not give error' do
      expect(validator).to validate_without_error(task)
    end
  end

  context 'when space_or_org is null' do
    let(:org) { nil }

    it 'does not give error' do
      expect(validator).to validate_without_error(task)
    end
  end

  context 'when app task limit is -1' do
    let(:quota_definition) { VCAP::CloudController::QuotaDefinition.make(app_task_limit: -1) }

    it 'does not give error' do
      expect(validator).to validate_without_error(task)
    end
  end

  context 'when the quota is exceeded' do
    before do
      VCAP::CloudController::TaskModel.make(app: app)
    end

    it 'registers an error' do
      expect(validator).to validate_with_error(task, :app_task_limit, error_name)
    end

    it 'adds the given error to the model' do
      validator.validate
      expect(task.errors.on(:app_task_limit)).to include(error_name)
    end
  end
end
