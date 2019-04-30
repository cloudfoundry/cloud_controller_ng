module VCAP::CloudController
  class DomainDelete
    def delete(domains)
      domains.each do |domain|
        Domain.db.transaction do
          domain.destroy
        end
      end

      []
    end
  end
end
