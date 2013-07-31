require 'spec_helper'

describe QuotaDefinitionPresenter do
  describe "#to_hash" do
    let(:quota_definition) { VCAP::CloudController::Models::QuotaDefinition.make }
    subject { QuotaDefinitionPresenter.new(quota_definition) }

    it "creates a valid JSON" do
      subject.to_hash.should eq({
        :metadata => {
          :guid => quota_definition.guid,
          :created_at => quota_definition.created_at.to_s,
          :updated_at => quota_definition.updated_at.to_s
        },
        :entity => {
          :name => quota_definition.name,
          :non_basic_services_allowed => quota_definition.non_basic_services_allowed,
          :total_services => quota_definition.total_services,
          :memory_limit => quota_definition.memory_limit,
          :trial_db_allowed => quota_definition.trial_db_allowed
        }
      })
    end
  end
end
