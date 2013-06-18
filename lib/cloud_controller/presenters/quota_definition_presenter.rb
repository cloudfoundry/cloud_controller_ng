require_relative 'abstract_presenter'

class QuotaDefinitionPresenter < AbstractPresenter
  def entity_hash
    {
      name: @object.name,
      non_basic_services_allowed: @object.non_basic_services_allowed,
      total_services: @object.total_services,
      memory_limit: @object.memory_limit,
      trial_db_allowed: @object.trial_db_allowed
    }
  end
end
