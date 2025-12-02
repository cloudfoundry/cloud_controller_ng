module Fog
  module Google
    class Monitoring
      ##
      # List the data points of the time series that match the metric and labels values and that have data points
      # in the interval
      #
      # @see https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.timeSeries/list
      class Real
        def list_timeseries(filter: nil, interval: nil, aggregation: nil, order_by: nil, page_size: nil, page_token: nil, view: nil)
          if filter.nil?
            raise ArgumentError.new("filter is required")
          end

          if interval.nil?
            raise ArgumentError.new("interval is required")
          end

          options = {
            :filter => filter,
            :interval_end_time => interval[:end_time],
            :interval_start_time => interval[:start_time],
            :order_by => order_by,
            :page_size => page_size,
            :page_token => page_token,
            :view => view
          }
          if options.key?(:interval)
            interval = options[:interval]
            parameters["interval.endTime"] = interval[:end_time] if interval.key?(:end_time)
            parameters["interval.startTime"] = interval[:start_time] if interval.key?(:start_time)
          end

          unless aggregation.nil?
            %i(alignment_period cross_series_reducer group_by_fields per_series_aligner).each do |k|
              if aggregation.key?(k)
                options["aggregation_#{k}".to_sym] = aggregation[k]
              end
            end
          end

          @monitoring.list_project_time_series("projects/#{@project}", **options)
        end
      end

      class Mock
        def list_timeseries(_options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
