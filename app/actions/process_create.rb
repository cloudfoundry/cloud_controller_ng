require 'repositories/process_event_repository'

module VCAP::CloudController
  class ProcessCreate
    def initialize(user_guid, user_email)
      @user_guid  = user_guid
      @user_email = user_email
    end

    def create(app, message)
      attrs = message.merge({
        diego:             true,
        space:             app.space,
        name:              "v3-#{app.name}-#{message[:type]}",
        metadata:          {},
        instances:         message[:type] == 'web' ? 1 : 0,
        health_check_type: message[:type] == 'web' ? 'port' : 'process'
      })

      process = nil
      app.class.db.transaction do
        process = app.add_process(attrs)

        RouteMappingModel.where(app_guid: app.guid, process_type: attrs[:type]).select_map(:route_guid).each do |route_guid|
          process.add_route_by_guid(route_guid)
        end

        Repositories::ProcessEventRepository.record_create(process, @user_guid, @user_email)
      end

      process
    end
  end
end
