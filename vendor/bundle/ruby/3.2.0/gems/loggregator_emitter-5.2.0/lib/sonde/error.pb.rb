## Generated from error.proto for events
require "beefcake"

module Sonde

  class Error
    include Beefcake::Message
  end

  class Error
    required :source, :string, 1
    required :code, :int32, 2
    required :message, :string, 3
  end
end
