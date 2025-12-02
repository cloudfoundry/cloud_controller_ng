require "fog/core/model"

module Fog
  module Google
    class Monitoring
      ##
      # A time series is a collection of data points that represents the value of a metric of a project over time.
      #
      # https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.timeSeries/list
      class Timeseries < Fog::Model
        attribute :metric
        attribute :resource
        attribute :metric_kind, :aliases => "metricKind"
        attribute :value_type, :aliases => "valueType"
        attribute :points
      end
    end
  end
end
