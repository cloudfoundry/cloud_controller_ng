module VCAP::CloudController
  rest_controller :App do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      read Permissions::SpaceManager
      full Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute  :name,                String
      attribute  :production,          Message::Boolean,    :default => false

      to_one     :space
      to_one     :stack,               :optional_in => :create

      attribute  :environment_json,    Hash,       :default => {}
      attribute  :memory,              Integer,    :default => 256
      attribute  :instances,           Integer,    :default => 1
      attribute  :disk_quota,          Integer,    :default => 1024

      attribute  :state,               String,     :default => "STOPPED"
      attribute  :command,             String,     :default => nil
      attribute  :console,             Message::Boolean, :default => false
      attribute  :debug,               String,     :default => nil

      # a URL pointing to a git repository
      # note that this will not match private git URLs, i.e. git@github.com:foo/bar.git
      attribute  :buildpack,           Message::GIT_URL, :default => nil
      attribute  :detected_buildpack,  String, :exclude_in => [:create, :update]

      to_many    :service_bindings,    :exclude_in => :create
      to_many    :routes

      to_many    :events
    end

    query_parameters :name, :space_guid, :organization_guid

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      memory_quota_errors = e.errors.on(:memory)

      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::AppNameTaken.new(attributes["name"])
      elsif memory_quota_errors
        if memory_quota_errors.include?(:quota_exceeded)
          Errors::AppMemoryQuotaExceeded.new
        end
      else
        Errors::AppInvalid.new(e.errors.full_messages)
      end
    end


    # Override this method because we want to enable the concept of
    # deleted apps. We allow enumeration only on apps which are NOT
    # marked as deleted.
    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      if opts.include?(:q)
        qp << "not_deleted"
        opts[:q] << ";not_deleted:t"
      end

      super(model, ds, qp, opts)
    end

    # Override this method because we want to enable the concept of
    # deleted apps. This is necessary because we have an app events table
    # which is a foreign key constraint on apps. Thus, we can't actually delete
    # the app itself. So, if an app is marked as deleted, we never want it to
    # be accessible to the end user and it becomes a Not Found Exception.
    # In the future, this method may be expanded to allow users of certain roles
    # to be able to access deleted apps.
    def find_id_and_validate_access(op, id)
      obj = super(op, id)
      if obj.deleted?
        raise self.class.not_found_exception.new(obj.guid)
      end
      obj
    end

    # Override this method because we want to enable the concept of
    # deleted apps. This is necessary because we have an app events table
    # which is a foreign key constraint on apps. Thus, we can't actually delete
    # the app itself, but instead mark it as deleted.
    #
    # @param [String] id The GUID of the object to delete.
    def delete(id)
      app = find_id_and_validate_access(:delete, id)
      recursive = params.has_key?("recursive") ? true : false

      if v2_api? && !recursive
        if app.has_deletable_associations?
          message = app.deletable_association_names.join(", ")
          raise VCAP::Errors::AssociationNotEmpty.new(message, app.class.table_name)
        end
      end

      app.soft_delete

      [ HTTP::NO_CONTENT, nil ]
    end

    private

    def before_modify(app)
      app.stage_async = %w(1 true).include?(params["stage_async"])
    end

    def after_modify(app)
      stager_response = app.last_stager_response
      if stager_response && stager_response.streaming_log_url
        set_header("X-App-Staging-Log", stager_response.streaming_log_url)
      end

      if app.dea_update_pending?
        DeaClient.update_uris(app)
      end
    end
  end
end
