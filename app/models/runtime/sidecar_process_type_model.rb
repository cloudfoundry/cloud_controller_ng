module VCAP::CloudController
  class SidecarProcessTypeModel < Sequel::Model(:sidecar_process_types)
    many_to_one :sidecar,
      class: 'VCAP::CloudController::SidecarModel',
      primary_key: :guid,
      key: :sidecar_guid,
      without_guid_generation: true
  end
end
