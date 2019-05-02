module VCAP::CloudController
  class DomainUpdate
    class InvalidDomain < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.domain_update')
    end

    def update(domain:, message:)
      Domain.db.transaction do
        MetadataUpdate.update(domain, message)
      end

      @logger.info("Finished updating metadata on domain #{domain.guid}")

      domain
    rescue Sequel::ValidationFailed => e
      raise InvalidDomain.new(e.message)
    end
  end
end
