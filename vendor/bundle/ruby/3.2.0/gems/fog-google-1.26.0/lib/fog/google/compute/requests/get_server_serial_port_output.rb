module Fog
  module Google
    class Compute
      class Mock
        def get_server_serial_port_output(_identity, _zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Returns the specified instance's serial port output.
        # @param [String] zone Zone for the given instance
        # @param [String] instance Instance scoping this request.
        # @param [Fixnum] port
        #   Specifies which COM or serial port to retrieve data from.
        #   Acceptable values are 1 to 4, inclusive. (Default: 1)
        # @param [Fixnum] start
        #   Returns output starting from a specific byte position.
        #   Use this to page through output when the output is too large to
        #   return in a single request. For the initial request,
        #   leave this field unspecified. For subsequent calls, this field
        #   should be set to the next value returned in the previous call.
        # @see https://cloud.google.com/compute/docs/reference/latest/instances/getSerialPortOutput
        def get_server_serial_port_output(identity, zone, port: nil, start: nil)
          @compute.get_instance_serial_port_output(
            @project,
            zone.split("/")[-1],
            identity,
            port: port,
            start: start
          )
        end
      end
    end
  end
end
