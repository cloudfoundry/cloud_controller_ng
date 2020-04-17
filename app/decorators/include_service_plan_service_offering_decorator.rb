module VCAP::CloudController
  class IncludeServicePlanServiceOfferingDecorator
    class << self
      def match?(include)
        include&.include?('service_offering')
      end

      def decorate(hash, service_plans)
        hash[:included] ||= {}
        service_offerings = service_plans.map(&:service).uniq

        hash[:included][:service_offerings] = service_offerings.sort_by(&:created_at).map do |service_offering|
          Presenters::V3::ServiceOfferingPresenter.new(service_offering).to_hash
        end

        hash
      end
    end
  end
end
