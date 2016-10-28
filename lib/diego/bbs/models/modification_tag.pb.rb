## Generated from modification_tag.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class ModificationTag
        include Beefcake::Message
      end

      class ModificationTag
        optional :epoch, :string, 1
        optional :index, :uint32, 2
      end
    end
  end
end
