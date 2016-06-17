require 'spec_helper'

RSpec.describe QuotaDefinitionPresenter do
  describe '#to_hash' do
    let(:quota_definition) { VCAP::CloudController::QuotaDefinition.make }
    subject { QuotaDefinitionPresenter.new(quota_definition) }

    it 'creates a valid JSON' do
      expect(subject.to_hash).to eq({
        metadata: {
          guid: quota_definition.guid,
          created_at: quota_definition.created_at.iso8601,
          updated_at: nil,
        },
        entity: {
          name: quota_definition.name,
          non_basic_services_allowed: quota_definition.non_basic_services_allowed,
          total_services: quota_definition.total_services,
          memory_limit: quota_definition.memory_limit,
          trial_db_allowed: false,
          total_routes: quota_definition.total_routes,
          instance_memory_limit: quota_definition.instance_memory_limit,
          total_private_domains: quota_definition.total_private_domains,
          app_instance_limit: quota_definition.app_instance_limit,
          app_task_limit: quota_definition.app_task_limit
        }
      })
    end
  end
end
