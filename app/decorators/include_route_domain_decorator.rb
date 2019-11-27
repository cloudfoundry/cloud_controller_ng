module VCAP::CloudController
  class IncludeRouteDomainDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(domain).include?(i) }
      end

      def decorate(hash, routes)
        hash[:included] ||= {}
        domain_guids = routes.map(&:domain_guid).uniq
        domains = Domain.where(guid: domain_guids).order(:name)

        hash[:included][:domains] = domains.map { |domain| Presenters::V3::DomainPresenter.new(domain).to_hash }
        hash
      end
    end
  end
end
