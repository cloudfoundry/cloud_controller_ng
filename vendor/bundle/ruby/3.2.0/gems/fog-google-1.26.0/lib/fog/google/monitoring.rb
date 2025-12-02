module Fog
  module Google
    class Monitoring < Fog::Service
      autoload :Mock, File.expand_path("../monitoring/mock", __FILE__)
      autoload :Real, File.expand_path("../monitoring/real", __FILE__)

      requires :google_project
      recognizes(
        :app_name,
        :app_version,
        :google_application_default,
        :google_auth,
        :google_client,
        :google_client_options,
        :google_key_location,
        :google_key_string,
        :google_json_key_location,
        :google_json_key_string
      )

      GOOGLE_MONITORING_API_VERSION    = "v3".freeze
      GOOGLE_MONITORING_BASE_URL       = "https://monitoring.googleapis.com/".freeze
      GOOGLE_MONITORING_API_SCOPE_URLS = %w(https://www.googleapis.com/auth/monitoring).freeze

      ##
      # MODELS
      model_path "fog/google/models/monitoring"

      # Timeseries
      model :timeseries
      collection :timeseries_collection

      # MetricDescriptors
      model :metric_descriptor
      collection :metric_descriptors

      # MonitoredResourceDescriptors
      model :monitored_resource_descriptor
      collection :monitored_resource_descriptors

      ##
      # REQUESTS
      request_path "fog/google/requests/monitoring"

      # Timeseries
      request :list_timeseries
      request :create_timeseries

      # MetricDescriptors
      request :get_metric_descriptor
      request :list_metric_descriptors
      request :create_metric_descriptor
      request :delete_metric_descriptor

      # MonitoredResourceDescriptors
      request :list_monitored_resource_descriptors
      request :get_monitored_resource_descriptor
    end
  end
end
