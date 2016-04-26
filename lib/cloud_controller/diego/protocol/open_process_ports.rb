module VCAP::CloudController
  module Diego
    class Protocol
      class OpenProcessPorts
        attr_reader :process

        def initialize(process)
          @process = process
        end

        def to_a
          return nil unless process.diego?
          return process.ports unless process.ports.nil?
          return process.docker_ports if process.docker?
          return [VCAP::CloudController::App::DEFAULT_HTTP_PORT] if process.type == 'web'
          []
        end
      end
    end
  end
end
