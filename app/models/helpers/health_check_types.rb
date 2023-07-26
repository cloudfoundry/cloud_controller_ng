module VCAP::CloudController
  class HealthCheckTypes
    PORT = 'port'.freeze
    PROCESS = 'process'.freeze
    HTTP = 'http'.freeze
    NONE = 'none'.freeze

    def self.constants_to_array
      [
        HTTP,
        NONE,
        PORT,
        PROCESS,
      ]
    end
  end
end
