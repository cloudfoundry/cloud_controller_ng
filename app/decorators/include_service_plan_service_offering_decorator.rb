module VCAP::CloudController
  class IncludeServicePlanServiceOfferingDecorator
    class << self
      def match?(include)
        include&.include?('service_offering')
      end

      def decorate(hash, service_plans)
        hash[:included] ||= {}
        service_offerings = Service.where(id: service_plans.map(&:service_id).uniq).
                            eager(Presenters::V3::ServiceOfferingPresenter.associated_resources).all

        hash[:included][:service_offerings] = service_offerings.sort_by(&:created_at).map do |service_offering|
          Presenters::V3::ServiceOfferingPresenter.new(service_offering).to_hash
        end

        hash
      end
    end
  end
end
