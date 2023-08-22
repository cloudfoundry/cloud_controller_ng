module VCAP::CloudController
  class UserAnnotationModel < Sequel::Model(:user_annotations)
    set_primary_key :id
    many_to_one :user,
                class: 'VCAP::CloudController::UserModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
