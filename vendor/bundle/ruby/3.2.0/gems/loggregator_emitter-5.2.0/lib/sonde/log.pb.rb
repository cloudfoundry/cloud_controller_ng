## Generated from log.proto for events
require "beefcake"

module Sonde

  class LogMessage
    include Beefcake::Message

    module MessageType
      OUT = 1
      ERR = 2
    end
  end

  class LogMessage
    required :message, :bytes, 1
    required :message_type, LogMessage::MessageType, 2
    required :timestamp, :int64, 3
    optional :app_id, :string, 4
    optional :source_type, :string, 5
    optional :source_instance, :string, 6
  end
end
