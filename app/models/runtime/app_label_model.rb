module VCAP::CloudController
  class AppLabelModel < Sequel::Model(:app_labels)
    many_to_one :app,
                class: 'VCAP::CloudController::AppModel',
                primary_key: :guid,
                key: :app_guid,
                without_guid_generation: true
  end
end
