# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models; end

require "sequel_plugins/vcap_validations"
require "sequel_plugins/vcap_serialization"
require "sequel_plugins/vcap_normalization"
require "sequel_plugins/vcap_relations"
require "sequel_plugins/vcap_guid"
require "sequel_plugins/update_or_create"

module Sequel::Plugins::VcapUserGroup
  module ClassMethods
    def define_user_group(name, opts = {})
      opts = opts.merge(
        :class => "VCAP::CloudController::Models::User",
        :join_table => "#{table_name}_#{name}",
        :right_key => :user_id
      )

      many_to_many(name, opts)
      add_association_dependencies name => :nullify
    end
  end
end

module Sequel::Plugins::VcapUserVisibility
  module ClassMethods
    def user_visible
      user = VCAP::CloudController::SecurityContext.current_user
      if(user)
        dataset.filter(user_visibility_filter(user))
      else
        dataset.filter(user_visibility_filter_with_admin_override(empty_dataset_filter))
      end
    end

    def user_visibility_filter(user)
      # TODO: replace with empty_dataset_filter once all perms are in place
      user_visibility_filter_with_admin_override(full_dataset_filter)
    end

    def user_visibility_filter_with_admin_override(filt)
      if VCAP::CloudController::SecurityContext.current_user_is_admin?
        full_dataset_filter
      else
        filt
      end
    end

    def full_dataset_filter
      ~{:id => nil}
    end

    def empty_dataset_filter
      {:id => nil}
    end
  end
end

module VCAP::CloudController::Models
  class InvalidRelation < StandardError; end
end

Sequel::Model.plugin :vcap_validations
Sequel::Model.plugin :vcap_serialization
Sequel::Model.plugin :vcap_normalization
Sequel::Model.plugin :vcap_relations
Sequel::Model.plugin :vcap_guid
Sequel::Model.plugin :vcap_user_group
Sequel::Model.plugin :vcap_user_visibility
Sequel::Model.plugin :update_or_create

Sequel::Model.plugin :typecast_on_load,
                     :name, :label, :provider, :description, :host

require "cloud_controller/models/billing_event"
require "cloud_controller/models/organization_start_event"
require "cloud_controller/models/app_start_event"
require "cloud_controller/models/app_stop_event"
require "cloud_controller/models/service_base_event"
require "cloud_controller/models/service_create_event"
require "cloud_controller/models/service_delete_event"

require "cloud_controller/models/app"
require "cloud_controller/models/domain"
require "cloud_controller/models/framework"
require "cloud_controller/models/organization"
require "cloud_controller/models/route"
require "cloud_controller/models/runtime"
require "cloud_controller/models/service"
require "cloud_controller/models/service_auth_token"
require "cloud_controller/models/service_binding"
require "cloud_controller/models/service_instance"
require "cloud_controller/models/service_plan"
require "cloud_controller/models/space"
require "cloud_controller/models/supported_buildpack"
require "cloud_controller/models/user"

require "cloud_controller/models/quota_definition"
