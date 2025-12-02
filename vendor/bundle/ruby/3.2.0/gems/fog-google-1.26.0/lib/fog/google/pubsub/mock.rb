module Fog
  module Google
    class Pubsub
      class Mock
        include Fog::Google::Shared

        def initialize(options)
          shared_initialize(options[:google_project], GOOGLE_PUBSUB_API_VERSION, GOOGLE_PUBSUB_BASE_URL)
        end

        def self.data
          @data ||= Hash.new do |hash, key|
            hash[key] = {
              :topics => {},
              :subscriptions => {}
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
