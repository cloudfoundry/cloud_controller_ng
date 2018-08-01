require_relative 'api_presenter'

class QuotaDefinitionPresenter < ApiPresenter
  def entity_hash
    {
      name: @object.name,
      non_basic_services_allowed: @object.non_basic_services_allowed,
      total_services: @object.total_services,
      memory_limit: @object.memory_limit,
      trial_db_allowed: false,
      total_routes: @object.total_routes,
      instance_memory_limit: @object.instance_memory_limit,
      total_private_domains: @object.total_private_domains,
      app_instance_limit: @object.app_instance_limit,
      app_task_limit: @object.app_task_limit
    }
  end
end
