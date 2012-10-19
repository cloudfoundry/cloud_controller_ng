# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Domain < Sequel::Model
    class InvalidSpaceRelation < InvalidRelation; end
    class InvalidOrganizationRelation < InvalidRelation; end

    DOMAIN_REGEX = /^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}$/ix.freeze

    many_to_one       :owning_organization,
                      :class => "VCAP::CloudController::Models::Organization"

    many_to_many      :organizations, :before_add => :validate_organization
    add_association_dependencies :organizations => :nullify

    one_to_many       :routes

    default_order_by  :name

    export_attributes :name, :owning_organization_guid, :wildcard
    import_attributes :name, :owning_organization_guid, :wildcard
    strip_attributes  :name

    many_to_many      :spaces, :before_add => :validate_space
    add_association_dependencies :spaces => :nullify

    def validate
      validates_presence :name
      validates_unique   :name
      validates_presence :wildcard

      if new? || column_changed?(:owning_organization)
        unless VCAP::CloudController::SecurityContext.current_user_is_admin?
          validates_presence :owning_organization
        end
      end

      validates_format DOMAIN_REGEX, :name
    end

    def validate_space(space)
      unless space && owning_organization && owning_organization.spaces.include?(space)
        raise InvalidSpaceRelation.new(space.guid)
      end
    end

    def validate_organization(org)
      return unless owning_organization
      unless org && owning_organization.id == org.id
        raise InvalidOrganizationRelation.new(org.guid)
      end
    end

    # For permission checks
    def organization
      owning_organization
    end

    def self.user_visibility_filter(user)
      orgs = Organization.filter({
        :managers => [user],
        :auditors => [user]
      }.sql_or)

      spaces = Space.filter({
        :developers => [user],
        :managers => [user],
        :auditors => [user]
      }.sql_or)

      user_visibility_filter_with_admin_override({
        :owning_organization => orgs,
        :spaces => spaces
      }.sql_or)
    end

    def self.default_serving_domain
      @default_serving_domain
    end

    def self.default_serving_domain_name=(name)
      logger = Steno.logger("cc.db.domain")
      @default_serving_domain_name = name
      unless name
        @default_serving_domain = nil
      else
        Domain.db.transaction do
          @default_serving_domain = Domain[:name => name]
          unless @default_serving_domain
            logger.info "creating default serving domain: #{name}"
            @default_serving_domain = Domain.new(:name => name)
            @default_serving_domain.save(:validate => false)
          else
            logger.info "reusing default serving domain: #{name}"
          end
        end
      end
      name
    end

    def self.default_serving_domain_name
      @default_serving_domain_name
    end
  end
end
