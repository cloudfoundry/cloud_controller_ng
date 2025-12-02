require "fog/core/collection"
require "fog/google/models/monitoring/timeseries"

module Fog
  module Google
    class Monitoring
      class TimeseriesCollection < Fog::Collection
        model Fog::Google::Monitoring::Timeseries

        ##
        # Lists all Timeseries.
        #
        # @param filter [String] A monitoring filter that specifies which time series should be returned.
        #   The filter must specify a single metric type, and can additionally specify metric labels and other
        #   information.
        # @param interval [Hash] Required. The time interval for which results should be returned.
        # @option interval [String] end_time Required RFC3339 timestamp marking the end of interval
        # @option interval [String] start_time Required RFC3339 timestamp marking start of interval.
        # @param aggregation [Hash] Optional object describing how to combine multiple time series to provide
        #   different views of the data. By default, the raw time series data is returned.
        # @option aggregation [String] alignment_period The alignment period for per-time series alignment.
        # @option aggregation [String] cross_series_reducer The approach to be used to align individual time series.
        # @option aggregation [String] group_by_fields The set of fields to preserve when crossSeriesReducer is specified.
        # @option aggregation [String] per_series_aligner The approach to be used to combine time series.
        # @param order_by [String] Specifies the order in which the points of the time series should be returned.
        #   By default, results are not ordered. Currently, this field must be left blank.
        # @param page_size [String]
        # @param page_token [String]
        # @param view [String] Specifies which information is returned about the time series.
        #
        # @return [Array<Fog::Google::Monitoring::Timeseries>] List of Timeseries.
        def all(filter: nil, interval: nil, aggregation: nil, order_by: nil, page_size: nil, page_token: nil, view: nil)
          data = service.list_timeseries(
            :filter => filter,
            :interval => interval,
            :aggregation => aggregation,
            :order_by => order_by,
            :page_size => page_size,
            :page_token => page_token,
            :view => view
          ).to_h[:time_series] || []

          load(data)
        end
      end
    end
  end
end
