module VCAP::CloudController
  class IncludeAppDomainDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(domain).include?(i) }
      end

      def decorate(hash, apps)
        hash[:included] ||= {}

        app_guids = apps.map(&:guid)
        domains = Domain.select_all(:domains).distinct.
                  join(:routes, domain_id: :id).
                  join(:route_mappings, route_guid: :routes__guid).
                  where(route_mappings__app_guid: app_guids).
                  order(:domains__created_at).
                  eager(Presenters::V3::DomainPresenter.associated_resources).
                  all

        hash[:included][:domains] = domains.map { |domain| Presenters::V3::DomainPresenter.new(domain).to_hash }
        hash
      end
    end
  end
end
