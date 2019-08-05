module VCAP::CloudController
  module Diego
    class Protocol
      class OpenProcessPorts
        attr_reader :process

        def initialize(process)
          @process = process
        end

        def to_a
          ports = process.ports || []

          if process.docker?
            needs_port_assignment = process.route_mappings.any? do |rm|
              rm.app_port == ProcessModel::NO_APP_PORT_SPECIFIED
            end

            if needs_port_assignment
              ports += if process.docker_ports.present?
                         process.docker_ports
                       else
                         ProcessModel::DEFAULT_PORTS
                       end
            elsif ports.empty? && process.docker_ports.present?
              ports += process.docker_ports
            end
          end

          ports += ProcessModel::DEFAULT_PORTS if process.web? && ports.empty?
          ports.uniq
        end
      end
    end
  end
end
