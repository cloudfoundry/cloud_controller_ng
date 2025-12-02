module Fog
  module Google
    class Monitoring
      class Mock
        include Fog::Google::Shared

        def initialize(options)
          shared_initialize(options[:google_project], GOOGLE_MONITORING_API_VERSION, GOOGLE_MONITORING_BASE_URL)
        end

        def self.data
          @data ||= Hash.new do |hash, key|
            hash[key] = {
              :timeseries => {},
              :monitored_resource_descriptor => {},
              :metric_descriptors => {}
            }
          end
        end

        def self.reset
          @data = nil
        end

        def data
          self.class.data[project]
        end

        def reset_data
          self.class.data.delete(project)
        end
      end
    end
  end
end
