module VCAP::CloudController
  class RevisionModel < Sequel::Model(:revisions)
    many_to_one :app,
      class: '::VCAP::CloudController::AppModel',
      key: :app_guid,
      primary_key: :guid,
      without_guid_generation: true

    many_to_one :droplet,
      class:             '::VCAP::CloudController::DropletModel',
      key: :droplet_guid,
      primary_key: :guid,
      without_guid_generation: true

    one_to_many :labels, class: 'VCAP::CloudController::RevisionLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::RevisionAnnotationModel', key: :resource_guid, primary_key: :guid
  end
end
