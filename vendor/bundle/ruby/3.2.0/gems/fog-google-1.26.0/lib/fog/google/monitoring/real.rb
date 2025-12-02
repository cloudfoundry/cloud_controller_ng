module Fog
  module Google
    class Monitoring
      class Real
        include Fog::Google::Shared

        attr_reader :monitoring

        def initialize(options)
          shared_initialize(options[:google_project], GOOGLE_MONITORING_API_VERSION, GOOGLE_MONITORING_BASE_URL)
          options[:google_api_scope_url] = GOOGLE_MONITORING_API_SCOPE_URLS.join(" ")

          initialize_google_client(options)
          @monitoring = ::Google::Apis::MonitoringV3::MonitoringService.new
          apply_client_options(@monitoring, options)
        end
      end
    end
  end
end
