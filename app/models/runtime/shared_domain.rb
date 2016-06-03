require 'models/runtime/domain'

module VCAP::CloudController
  class SharedDomain < Domain
    set_dataset(shared_domains)

    add_association_dependencies routes: :destroy

    export_attributes :name, :router_group_guid, :router_group_type
    import_attributes :name, :router_group_guid
    strip_attributes :name
    attr_accessor :router_group_type

    def as_summary_json
      {
        guid: guid,
        name: name,
        router_group_guid: router_group_guid,
        router_group_type: router_group_type
      }
    end

    def self.find_or_create(name, rtr_guid=nil)
      logger = Steno.logger('cc.db.domain')
      domain = nil

      Domain.db.transaction do
        domain = SharedDomain[name: name]

        if domain
          logger.info "reusing default serving domain: #{name}"
        elsif rtr_guid
          domain = SharedDomain.new(name: name, router_group_guid: rtr_guid)
        else
          domain = SharedDomain.new(name: name)
        end

        logger.info "creating shared serving domain: #{name}"
        domain.save
      end

      domain
    rescue => e
      err = e.class.new("Error for shared domain name #{name}: #{e.message}")
      err.set_backtrace(e.backtrace)
      raise err
    end

    def shared?
      true
    end

    def tcp?
      self.router_group_guid.present?
    end

    def addable_to_organization!(organization)
    end

    def transient_attrs
      router_group_type.blank? ? [] : [:router_group_type]
    end
  end
end
