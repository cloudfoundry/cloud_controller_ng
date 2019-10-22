module VCAP::CloudController
  module Jobs
    # TODO: add unit tests for this so it can be relied on in other unit tests
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
