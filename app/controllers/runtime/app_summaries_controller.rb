module VCAP::CloudController
  class AppSummariesController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get "#{path_guid}/summary", :summary
    def summary(guid)
      app = find_guid_and_validate_access(:read, guid)
      app_info = {
        guid: app.guid,
        name: app.name,
        routes: app.routes.map(&:as_summary_json),
        running_instances: app.running_instances,
        services: app.service_bindings.map { |service_binding| service_binding.service_instance.as_summary_json },
        available_domains: app.space.domains.map(&:as_summary_json)
      }.merge(app.to_hash)

      Yajl::Encoder.encode(app_info)
    end
  end
end
