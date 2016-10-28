## Generated from network.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class Network
        include Beefcake::Message

        class PropertiesEntry
          include Beefcake::Message
        end
      end

      class Network

        class PropertiesEntry
          optional :key, :string, 1
          optional :value, :string, 2
        end
        repeated :properties, Network::PropertiesEntry, 1
      end
    end
  end
end
