## Generated from cached_dependency.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class CachedDependency
        include Beefcake::Message
      end

      class CachedDependency
        optional :name, :string, 1
        optional :from, :string, 2
        optional :to, :string, 3
        optional :cache_key, :string, 4
        optional :log_source, :string, 5
        optional :checksum_algorithm, :string, 6
        optional :checksum_value, :string, 7
      end
    end
  end
end
