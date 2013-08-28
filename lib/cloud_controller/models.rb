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
  module InstanceMethods
    def user_visible_relationship_dataset(name, user = VCAP::CloudController::SecurityContext.current_user)
      associated_model = self.class.association_reflection(name).associated_class
      relationship_dataset(name).filter(associated_model.user_visibility(user))
    end
  end

  module ClassMethods
    # controller calls this to get the list of objects
    def user_visible(user = VCAP::CloudController::SecurityContext.current_user)
      dataset.filter(user_visibility(user))
    end

    def user_visibility(user)
      if VCAP::CloudController::SecurityContext.admin?
        full_dataset_filter
      elsif user
        user_visibility_filter(user)
      else
        {:id => nil}
      end
    end

    # this is overridden by models to determine which objects a user can see
    def user_visibility_filter(_)
      {:id => nil}
    end

    def full_dataset_filter
      Sequel.~({:id => nil})
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

require "vcap/sequel_add_association_dependencies_monkeypatch"

require "models/core/billing_event"
require "models/core/organization_start_event"
require "models/core/app_start_event"
require "models/core/app_stop_event"
require "models/core/app_event"
require "models/core/app"
require "models/core/domain"
require "models/core/event"
require "models/core/organization"
require "models/core/quota_definition"
require "models/core/route"
require "models/core/task"
require "models/core/space"
require "models/core/stack"
require "models/core/user"

require "models/services/service"
require "models/services/service_auth_token"
require "models/services/service_binding"
require "models/services/service_instance"
require "models/services/managed_service_instance"
require "models/services/user_provided_service_instance"
require "models/services/service_broker"
require "models/services/service_broker_registration"
require "models/services/service_plan"
require "models/services/service_plan_visibility"
require "models/services/service_base_event"
require "models/services/service_create_event"
require "models/services/service_delete_event"

require File.expand_path("../../../app/access/base_access.rb", __FILE__)
Dir[File.expand_path("../../../app/access/**/*.rb", __FILE__)].each do |file|
  require file
end
