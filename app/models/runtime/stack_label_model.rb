module VCAP::CloudController
  class StackLabelModel < Sequel::Model(:stack_labels)
    many_to_one :stack,
      class: 'VCAP::CloudController::Stack',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
