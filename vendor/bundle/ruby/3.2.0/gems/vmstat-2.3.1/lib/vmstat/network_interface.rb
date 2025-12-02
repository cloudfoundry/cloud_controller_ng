module Vmstat
  # Gathered the network interface information.
  # @attr [Symbol] name the system name for the network interface.
  # @attr [Fixnum] in_bytes the number od bytes that where received inbound.
  # @attr [Fixnum] in_errors the number of errors that where received inbound.
  # @attr [Fixnum] in_drops the number of drops that where received inbound.
  # @attr [Fixnum] out_bytes the number od bytes that where send outbound.
  # @attr [Fixnum] out_errors the number od errors that where send outbound.
  # @attr [Fixnum] type the type of the interface (bsd numbers)
  class NetworkInterface < Struct.new(:name, :in_bytes, :in_errors, :in_drops,
                                      :out_bytes, :out_errors, :type)

    # The type of ethernet devices on freebsd/mac os x
    ETHERNET_TYPE = 0x06

    # The type of loopback devices on freebsd/mac os x
    LOOPBACK_TYPE = 0x18

    # Checks if this network interface is a loopback device.
    # @return [TrueClass, FalseClass] true if it is a loopback device, false
    #   otherwise.
    def loopback?
      type == LOOPBACK_TYPE
    end

    # Checks if this network interface is a ethernet device.
    # @return [TrueClass, FalseClass] true if it is a ethernet device, false
    #   otherwise.
    def ethernet?
      type == ETHERNET_TYPE
    end
  end
end
