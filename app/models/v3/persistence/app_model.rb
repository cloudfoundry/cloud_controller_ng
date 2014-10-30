module VCAP::CloudController
  class AppModel < Sequel::Model(:apps_v3)
    one_to_many :processes, class: App, key: :app_guid, primary_key: :guid

    def self.user_visibility_filter(user)
      true
    end
  end
end
