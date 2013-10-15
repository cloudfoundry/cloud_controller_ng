require "vcap/component"

module VCAP::CloudController
  class Varz
    def self.bump_user_count
      ::VCAP::Component.varz.synchronize do
        ::VCAP::Component.varz[:cc_user_count] = User.count
      end
    end
  end
end