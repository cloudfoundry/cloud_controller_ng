module VCAP::CloudController
  class HealthCheckTypes
    PORT = 'port'.freeze
    PROCESS = 'process'.freeze
    HTTP = 'http'.freeze
    NONE = 'none'.freeze

    def self.all_types
      [
        HTTP,
        NONE,
        PORT,
        PROCESS,
      ]
    end

    def self.readiness_types
      self.all_types - [NONE]
    end
  end
end
