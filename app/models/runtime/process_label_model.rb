module VCAP::CloudController
  class ProcessLabelModel < Sequel::Model(:process_labels)
    many_to_one :process,
      class: 'VCAP::CloudController::ProcessModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
