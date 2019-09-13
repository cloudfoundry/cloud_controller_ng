module VCAP::CloudController
  class UserLabelModel < Sequel::Model(:user_labels)
    many_to_one :user,
      class: 'VCAP::CloudController::UserModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
