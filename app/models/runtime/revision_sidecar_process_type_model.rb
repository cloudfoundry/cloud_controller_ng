module VCAP::CloudController
  class RevisionSidecarProcessTypeModel < Sequel::Model(:revision_sidecar_process_types)
    many_to_one :revision_sidecar,
                class: 'VCAP::CloudController::RevisionSidecarModel',
                primary_key: :guid,
                key: :revision_sidecar_guid,
                without_guid_generation: true

    def around_save
      yield
    rescue Sequel::UniqueConstraintViolation => e
      raise e unless e.message.include?('revision_sidecar_process_types_revision_sidecar_guid_type_index')

      errors.add(%i[revision_sidecar_guid type], "Sidecar is already associated with process type #{type}")
      raise Sequel::ValidationFailed.new(self)
    end

    def validate
      super
      validates_presence [:type]
      validates_max_length 255, :type, message: Sequel.lit('Process type is too long (maximum is 255 characters)')
    end
  end
end
