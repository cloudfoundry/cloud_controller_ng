require 'process_create_from_app_droplet'

module VCAP::CloudController
  class AppAssignDroplet
    class Error < StandardError; end
    class InvalidApp < Error; end
    class InvalidDroplet < Error; end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def assign(app, droplet)
      unable_to_assign! unless droplet.present? && droplet_associated?(app, droplet)

      app.db.transaction do
        app.lock!

        app.update(droplet_guid: droplet.guid)

        record_assign_droplet_event(app, droplet)
        create_processes(app)

        app.save
      end

      app
    rescue ProcessCreateFromAppDroplet::ProcessTypesNotFound => e
      raise InvalidDroplet.new(e.message)
    rescue ProcessCreateFromAppDroplet::SidecarMemoryLessThanProcessMemory, Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def record_assign_droplet_event(app, droplet)
      Repositories::AppEventRepository.new.record_app_map_droplet(
        app,
        app.space,
        @user_audit_info,
        { droplet_guid: droplet.guid }
      )
    end

    def create_processes(app)
      ProcessCreateFromAppDroplet.new(@user_audit_info).create(app)
    end

    def droplet_associated?(app, droplet)
      droplet.app.pk == app.pk
    end

    def unable_to_assign!
      raise InvalidDroplet.new('Unable to assign current droplet. Ensure the droplet exists and belongs to this app.')
    end
  end
end
