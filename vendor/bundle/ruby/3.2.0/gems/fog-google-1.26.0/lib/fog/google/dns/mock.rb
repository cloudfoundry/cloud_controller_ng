module Fog
  module Google
    class DNS
      class Mock
        include Fog::Google::Shared

        def initialize(options)
          shared_initialize(options[:google_project], GOOGLE_DNS_API_VERSION, GOOGLE_DNS_BASE_URL)
        end

        def self.data(_api_version)
          @data ||= {}
        end

        def self.reset
          @data = nil
        end

        def data(project = @project)
          self.class.data(api_version)[project] ||= {
            :managed_zones => {},
            :resource_record_sets => {},
            :changes => {}
          }
        end

        def reset_data
          self.class.data(api_version).delete(@project)
        end
      end
    end
  end
end
