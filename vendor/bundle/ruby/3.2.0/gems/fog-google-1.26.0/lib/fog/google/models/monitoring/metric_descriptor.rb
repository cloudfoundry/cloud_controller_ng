require "fog/core/model"

module Fog
  module Google
    class Monitoring
      ##
      # A metricDescriptor defines a metric type and its schema.
      #
      # @see https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.metricDescriptors#MetricDescriptor
      class MetricDescriptor < Fog::Model
        identity :name

        attribute :description
        attribute :display_name, :aliases => "displayName"
        attribute :labels
        attribute :metric_kind, :aliases => "metricKind"
        attribute :type
        attribute :value_type, :aliases => "valueType"
        attribute :unit
      end
    end
  end
end
