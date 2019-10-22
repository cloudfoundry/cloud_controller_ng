module VCAP::CloudController
  module Jobs
    module Queues
      def self.local(config)
        "cc-#{config.get(:name)}-#{config.get(:index)}"
      end

      def self.generic
        'cc-generic'
      end
    end
  end
end
