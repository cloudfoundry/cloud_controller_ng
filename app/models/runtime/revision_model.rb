module VCAP::CloudController
  class RevisionModel < Sequel::Model(:revisions)
    many_to_one :app,
      class: '::VCAP::CloudController::AppModel',
      key: :app_guid,
      primary_key: :guid,
      without_guid_generation: true
  end
end
