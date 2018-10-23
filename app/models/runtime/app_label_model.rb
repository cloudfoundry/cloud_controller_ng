module VCAP::CloudController
  class AppLabelModel < Sequel::Model(:app_labels)
    RESOURCE_GUID_COLUMN = :app_guid

    many_to_one :app,
                class: 'VCAP::CloudController::AppModel',
                primary_key: :guid,
                key: :app_guid,
                without_guid_generation: true
  end
end
