## Generated from log_message.proto for logmessage
require "beefcake"


class LogMessage
  include Beefcake::Message

  module MessageType
    OUT = 1
    ERR = 2
  end

  required :message, :bytes, 1
  required :message_type, LogMessage::MessageType, 2
  required :timestamp, :sint64, 3
  required :app_id, :string, 4
  optional :source_id, :string, 6
  repeated :drain_urls, :string, 7
  optional :source_name, :string, 8

end

class LogEnvelope
  include Beefcake::Message


  required :routing_key, :string, 1
  required :signature, :bytes, 2
  required :log_message, LogMessage, 3

end
