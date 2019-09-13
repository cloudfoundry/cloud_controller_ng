module VCAP::CloudController
  class UserAnnotationModel < Sequel::Model(:user_annotations)
    many_to_one :user,
      class: 'VCAP::CloudController::UserModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
