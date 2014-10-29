module VCAP::CloudController
  class AppModel < Sequel::Model(:apps_v3)

    def self.user_visibility_filter(user)
      true
    end

  end
end
