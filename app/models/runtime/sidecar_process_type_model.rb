module VCAP::CloudController
  class SidecarProcessTypeModel < Sequel::Model(:sidecar_process_types)
    many_to_one :sidecar,
      class: 'VCAP::CloudController::SidecarModel',
      primary_key: :guid,
      key: :sidecar_guid,
      without_guid_generation: true

    def validate
      super
      validates_presence [:type]
      validates_max_length 255, :type, message: Sequel.lit('Process type is too long (maximum is 255 characters)')
    end
  end
end
