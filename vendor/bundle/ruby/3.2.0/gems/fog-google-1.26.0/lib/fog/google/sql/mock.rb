module Fog
  module Google
    class SQL
      class Mock
        include Fog::Google::Shared

        def initialize(options)
          shared_initialize(options[:google_project], GOOGLE_SQL_API_VERSION, GOOGLE_SQL_BASE_URL)
        end

        def self.data
          @data ||= Hash.new do |hash, key|
            hash[key] = {
              :backup_runs => {},
              :instances => {},
              :operations => {},
              :ssl_certs => {}
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

        def random_operation
          "operation-#{Fog::Mock.random_numbers(13)}-#{Fog::Mock.random_hex(13)}-#{Fog::Mock.random_hex(8)}"
        end
      end
    end
  end
end
