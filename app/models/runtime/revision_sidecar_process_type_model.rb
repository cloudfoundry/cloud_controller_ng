module VCAP::CloudController
  class RevisionSidecarProcessTypeModel < Sequel::Model(:revision_sidecar_process_types)
    many_to_one :revision_sidecar,
      class: 'VCAP::CloudController::RevisionSidecarModel',
      primary_key: :guid,
      key: :revision_sidecar_guid,
      without_guid_generation: true

    def validate
      super
      validates_presence [:type]
      validates_max_length 255, :type, message: Sequel.lit('Process type is too long (maximum is 255 characters)')
      validates_unique [:revision_sidecar_guid, :type], message: Sequel.lit("Sidecar is already associated with process type #{type}")
    end
  end
end
