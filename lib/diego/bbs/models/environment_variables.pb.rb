## Generated from environment_variables.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class EnvironmentVariable
        include Beefcake::Message
      end

      class EnvironmentVariable
        optional :name, :string, 1
        optional :value, :string, 2
      end
    end
  end
end
