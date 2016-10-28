## Generated from security_group.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class PortRange
        include Beefcake::Message
      end

      class ICMPInfo
        include Beefcake::Message
      end

      class SecurityGroupRule
        include Beefcake::Message
      end

      class PortRange
        optional :start, :uint32, 1
        optional :end, :uint32, 2
      end

      class ICMPInfo
        optional :type, :int32, 1
        optional :code, :int32, 2
      end

      class SecurityGroupRule
        optional :protocol, :string, 1
        repeated :destinations, :string, 2
        repeated :ports, :uint32, 3
        optional :port_range, PortRange, 4
        optional :icmp_info, ICMPInfo, 5
        optional :log, :bool, 6
      end
    end
  end
end
