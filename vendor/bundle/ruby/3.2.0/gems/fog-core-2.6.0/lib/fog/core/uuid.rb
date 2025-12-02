require "securerandom"

module Fog
  class UUID
    class << self
      def uuid
        SecureRandom.uuid
      end

      # :nodoc: This method is used by other plugins, so preserve it for the compatibility
      def supported?
        SecureRandom.respond_to?(:uuid)
      end
    end
  end
end
