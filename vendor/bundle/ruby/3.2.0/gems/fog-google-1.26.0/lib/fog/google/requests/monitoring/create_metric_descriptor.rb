module Fog
  module Google
    class Monitoring
      class Real
        ##
        # Create a metric descriptor. User-created metric descriptors define custom metrics.
        # @param metric_type [String] Required - the metric type. User-created metric descriptors should start
        #   with custom.googleapis.com.
        # @param unit [String]  The unit in which the metric value is reported.
        #   It is only applicable if the valueType is INT64, DOUBLE, or DISTRIBUTION.
        # @param value_type [String]  Whether the measurement is an integer, a floating-point number, etc.
        #   Some combinations of metricKind and valueType might not be supported.
        # @param description [String]  A detailed description of the metric, which can be used in documentation.
        # @param display_name [String]  A concise name for the metric, which can be displayed in user interfaces.
        #   Use sentence casing without an ending period, for example "Request count".
        # @param labels [Array<Hash>] A list of label hash objects that can be used to describe a specific
        #   instance of this metric type.
        # @option labels [String] key The label key.
        # @option labels [String] value_type The type of data that can be assigned to the label.
        # @option labels [String] description A human-readable description for the label.
        # @param metric_kind [String]  The pagination token, which is used to page through large result sets.
        #
        # @return [::Google::Apis::MonitoringV3::MetricDescriptor] created metric descriptor
        # @see https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.metricDescriptors/create
        def create_metric_descriptor(metric_type: nil, unit: nil, value_type: nil,
                                     description: nil, display_name: nil, labels: [], metric_kind: nil)
          metric_descriptor = ::Google::Apis::MonitoringV3::MetricDescriptor.new(
            name: "projects/#{@project}/metricDescriptors/#{metric_type}",
            type: metric_type,
            unit: unit,
            value_type: value_type,
            description: description,
            display_name: display_name,
            labels: labels.map { |l| ::Google::Apis::MonitoringV3::LabelDescriptor.new(**l) },
            metric_kind: metric_kind
          )

          @monitoring.create_project_metric_descriptor("projects/#{@project}", metric_descriptor)
        end
      end

      class Mock
        def create_metric_descriptor(**_args)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
