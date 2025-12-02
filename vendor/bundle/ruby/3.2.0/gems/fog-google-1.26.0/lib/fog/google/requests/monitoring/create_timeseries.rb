module Fog
  module Google
    class Monitoring
      class Real
        ##
        # Create a timeseries. User-created time series should only be used with custom metrics.
        #
        # @param timeseries [Array<Hash>] Timeseries to create/update.
        #   @see https://cloud.google.com/monitoring/api/ref_v3/rest/v3/TimeSeries for expected format.
        # @see https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.timeSeries/create
        #
        def create_timeseries(timeseries: [])
          request = ::Google::Apis::MonitoringV3::CreateTimeSeriesRequest.new(
            time_series: timeseries
          )
          @monitoring.create_project_time_series("projects/#{@project}", request)
        end
      end

      class Mock
        def create_timeseries(_timeseries: [])
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
