# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :App do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      read Permissions::SpaceManager
      read Permissions::SpaceManager
      full Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute  :name,                String
      attribute  :production,          Message::Boolean,    :default => false
      to_one     :space
      to_one     :runtime
      to_one     :framework
      attribute  :environment_json,    Hash,       :default => {}
      attribute  :memory,              Integer,    :default => 256
      attribute  :instances,           Integer,    :default => 1
      attribute  :file_descriptors,    Integer,    :default => 256
      attribute  :disk_quota,          Integer,    :default => 256

      # TODO: renable exclude_in => :create for state, but not until it is
      # coordinated with ilia and ramnivas
      attribute  :state,               String,     :default => "STOPPED" # , :exclude_in => :create
      attribute  :command,             String,     :default => nil
      attribute  :console,             Message::Boolean, :default => false

      to_many    :service_bindings,    :exclude_in => :create
      to_many    :routes
    end

    query_parameters :name, :space_guid, :organization_guid, :framework_guid, :runtime_guid

    def after_update(app, changes)
      AppStager.stage_app(app) if app.needs_staging?

      return unless app.staged?
      if changes.include?(:state)
        if app.started?
          DeaClient.start(app)
        elsif app.stopped?
          DeaClient.stop(app)
        end
      elsif changes.include?(:instances) && app.started?
        delta = changes[:instances][1] - changes[:instances][0]
        DeaClient.change_running_instances(app, delta)
      end

      send_droplet_updated_message(app)
    end

    def send_droplet_updated_message(app)
      json = Yajl::Encoder.encode(:droplet => app.guid,
                                  :cc_partition => config[:cc_partition])
      MessageBus.publish("droplet.updated", json)
      nil
    end

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::AppNameTaken.new(attributes["name"])
      else
        Errors::AppInvalid.new(e.errors.full_messages)
      end
    end

    private

    def after_modify(app)
      if app.dea_update_pending?
        DeaClient.update_uris(app)
      end
    end
  end
end
