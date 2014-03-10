require_relative 'api_presenter'

class QuotaDefinitionPresenter < ApiPresenter
  def entity_hash
    {
      name: @object.name,
      non_basic_services_allowed: @object.non_basic_services_allowed,
      total_services: @object.total_services,
      memory_limit: @object.memory_limit,
      trial_db_allowed: false
    }
  end
end
