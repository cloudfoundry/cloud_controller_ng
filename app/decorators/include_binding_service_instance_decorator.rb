module VCAP::CloudController
  class IncludeBindingServiceInstanceDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(service_instance).include?(i) }
      end

      def decorate(hash, bindings)
        hash.deep_merge({
          included: {
            service_instances: service_instances(bindings).map { |i| Presenters::V3::ServiceInstancePresenter.new(i).to_hash }
          }
        })
      end

      private

      def service_instances(bindings)
        ServiceInstance.where(guid: bindings.map { |b| b[:service_instance_guid] }).order(:created_at)
      end
    end
  end
end
