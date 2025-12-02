## Generated from uuid.proto for events
require "beefcake"

module Sonde

  class UUID
    include Beefcake::Message
  end

  class UUID
    required :low, :uint64, 1
    required :high, :uint64, 2
  end
end
