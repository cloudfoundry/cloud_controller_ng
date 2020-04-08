module VCAP::CloudController
  module Jobs
    module Queues
      def self.local(config)
        if config.get(:name).blank?
          "cc-#{ENV['HOSTNAME']}"
        else
          "cc-#{config.get(:name)}-#{config.get(:index)}"
        end
      end

      def self.generic
        'cc-generic'
      end
    end
  end
end
