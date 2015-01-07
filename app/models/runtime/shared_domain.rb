require 'models/runtime/domain'

module VCAP::CloudController
  class SharedDomain < Domain
    set_dataset(shared_domains)

    add_association_dependencies routes: :destroy

    export_attributes :name
    import_attributes :name
    strip_attributes :name

    def as_summary_json
      {
        guid: guid,
        name: name,
      }
    end

    def self.find_or_create(name)
      logger = Steno.logger('cc.db.domain')
      domain = nil

      Domain.db.transaction do
        domain = SharedDomain[name: name]

        if domain
          logger.info "reusing default serving domain: #{name}"
        else
          logger.info "creating shared serving domain: #{name}"
          domain = SharedDomain.new(name: name)
          domain.save
        end
      end

      domain
    end

    def shared?
      true
    end

    def addable_to_organization!(organization)
    end
  end
end
