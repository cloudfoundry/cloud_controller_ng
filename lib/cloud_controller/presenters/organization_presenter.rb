require_relative 'abstract_presenter'
require_relative 'quota_definition_presenter'

class OrganizationPresenter < AbstractPresenter
  def entity_hash
    {
      name: @object.name,
      billing_enabled: @object.billing_enabled,
      status: @object.status,
      quota_definition: QuotaDefinitionPresenter.new(@object.quota_definition).to_hash
    }
  end
end
