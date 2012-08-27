# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Space < Sequel::Model
    class InvalidRelation          < StandardError; end
    class InvalidDeveloperRelation < InvalidRelation; end
    class InvalidAuditorRelation   < InvalidRelation; end
    class InvalidManagerRelation   < InvalidRelation; end
    class InvalidDomainRelation    < InvalidRelation; end

    many_to_one       :organization

    define_user_group :developers, :reciprocal => :spaces,
                      :before_add => :validate_developer

    define_user_group :managers, :reciprocal => :managed_spaces,
                      :before_add => :validate_manager

    define_user_group :auditors, :reciprocal => :audited_spaces,
                      :before_add => :validate_auditor

    one_to_many       :apps
    one_to_many       :service_instances

    many_to_many      :domains, :before_add => :validate_domain
    add_association_dependencies :domains => :nullify

    one_to_many       :default_users,
                      :class => "VCAP::CloudController::Models::User",
                      :key => :default_space_id
    add_association_dependencies :default_users => :nullify


    default_order_by  :name

    export_attributes :name, :organization_guid

    import_attributes :name, :organization_guid, :developer_guids,
                      :manager_guids, :auditor_guids, :domain_guids

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :organization
      validates_unique   [:organization_id, :name]
    end

    def validate_developer(user)
      unless organization && organization.users.include?(user)
        # TODO: unlike most other validations, this is *NOT* being enforced by
        # the db
        raise InvalidDeveloperRelation.new(user.guid)
      end
    end

    def validate_manager(user)
      unless organization && organization.users.include?(user)
        raise InvalidManagerRelation.new(user.guid)
      end
    end

    def validate_auditor(user)
      unless organization && organization.users.include?(user)
        raise InvalidAuditorRelation.new(user.guid)
      end
    end

    def validate_domain(domain)
      return if domain && domain.owning_organization.nil?
      unless (domain && organization &&
              domain.owning_organization_id &&
              domain.owning_organization_id == organization.id)
        raise InvalidDomainRelation.new(domain.guid)
      end
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        :organization => user.organizations_dataset
      )
    end
  end
end
