module VCAP::CloudController
  class IncludeRouteDomainDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w[domain].include?(i) }
      end

      def decorate(hash, routes)
        hash[:included] ||= {}
        domain_ids = routes.map(&:domain_id).uniq
        domains = Domain.where(id: domain_ids).order(:name).
                  eager(Presenters::V3::DomainPresenter.associated_resources).all

        hash[:included][:domains] = domains.map { |domain| Presenters::V3::DomainPresenter.new(domain).to_hash }
        hash
      end
    end
  end
end
