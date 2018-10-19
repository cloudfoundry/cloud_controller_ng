module VCAP::CloudController
  class AppLabel < Sequel::Model
    many_to_one :app,
                class: 'VCAP::CloudController::AppModel',
                primary_key: :guid,
                key: :app_guid,
                without_guid_generation: true
  end
end
