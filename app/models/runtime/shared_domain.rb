require 'models/runtime/domain'
require 'cloud_controller/routing_api/routing_api_client'

module VCAP::CloudController
  class SharedDomain < Domain
    set_dataset(shared_domains)

    add_association_dependencies routes: :destroy

    export_attributes :name, :internal, :router_group_guid, :router_group_type
    import_attributes :name, :internal, :router_group_guid
    strip_attributes :name
    attr_accessor :router_group_type

    def as_summary_json
      {
        guid: guid,
        name: name,
        internal: internal,
        router_group_guid: router_group_guid,
        router_group_type: router_group_type
      }
    end

    def self.find_or_create(name:, router_group_guid: nil, internal: false)
      logger = Steno.logger('cc.db.domain')
      domain = nil

      Domain.db.transaction do
        domain = SharedDomain.find(name: name)

        if domain
          logger.info "reusing default serving domain: #{name}"
          if domain.internal? != !!internal
            logger.warn("Domain '#{name}' already exists. Skipping updates of internal status")
          end

          if domain.router_group_guid != router_group_guid
            logger.warn("Domain '#{name}' already exists. Skipping updates of router_group_guid")
          end
        else
          logger.info "creating shared serving domain: #{name}"
          domain = SharedDomain.create(name: name, router_group_guid: router_group_guid, internal: internal)
        end
      end

      domain
    rescue => e
      err = e.class.new("Error for shared domain name #{name}: #{e.message}")
      err.set_backtrace(e.backtrace)
      raise err
    end

    def validate
      super

      validate_internal_domain if internal?
    end

    def shared?
      true
    end

    def protocols
      return ['tcp'] if self.tcp?

      ['http']
    end

    def tcp?
      if router_group_guid.present?
        if @router_group_type.nil?
          @router_group_type = router_group.nil? ? '' : router_group.type
        end

        return @router_group_type.eql?('tcp')
      end

      false
    end

    def router_group
      @router_group ||= routing_api_client.router_group(router_group_guid)
    end

    def addable_to_organization!(organization); end

    def transient_attrs
      router_group_type.blank? ? [] : [:router_group_type]
    end

    def routing_api_client
      @routing_api_client ||= CloudController::DependencyLocator.instance.routing_api_client
    end

    private

    def validate_internal_domain
      if router_group_guid.present?
        errors.add(:router_group_guid, 'cannot be specified for internal domains')
      end
    end
  end
end
