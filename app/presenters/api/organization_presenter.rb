require_relative 'api_presenter'
require_relative 'quota_definition_presenter'
require_relative 'space_presenter'
require_relative 'user_presenter'

class OrganizationPresenter < ApiPresenter
  def entity_hash
    {
      name: @object.name,
      billing_enabled: @object.billing_enabled,
      status: @object.status,
      spaces: @object.spaces.map { |space| SpacePresenter.new(space).to_hash },
      quota_definition: QuotaDefinitionPresenter.new(@object.quota_definition).to_hash,
      managers: @object.managers.map { |manager| UserPresenter.new(manager).to_hash }
    }
  end
end
