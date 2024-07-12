module VCAP::CloudController
  class Buildpack < Sequel::Model
    plugin :list
    plugin :single_table_inheritance, :lifecycle,
      model_map: {
        VCAP::CloudController::Lifecycles::BUILDPACK => "VCAP::CloudController::ClassicBuildpack",
        VCAP::CloudController::Lifecycles::CNB => "VCAP::CloudController::CNBBuildpack"
      }

    export_attributes :name, :stack, :position, :enabled, :locked, :filename
    import_attributes :name, :stack, :position, :enabled, :locked, :filename, :key

    PACKAGE_STATES = [
      CREATED_STATE = 'AWAITING_UPLOAD'.freeze,
      READY_STATE = 'READY'.freeze
    ].map(&:freeze).freeze

    one_to_many :labels, class: 'VCAP::CloudController::BuildpackLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::BuildpackAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    def self.user_visibility_filter(_user)
      full_dataset_filter
    end

    def validate
      validates_unique %i[name stack]
      validates_format(/\A(\w|-)+\z/, :name, message: 'can only contain alphanumeric characters')

      validate_stack_existence
      validate_stack_change
      validate_multiple_nil_stacks
    end

    def locked?
      !!locked
    end

    def enabled?
      !!enabled
    end

    def staging_message
      { buildpack_key: key }
    end

    # This is used in the serialization of apps to JSON. The buildpack object is left in the hash for the app, then the
    # JSON encoder calls to_json on the buildpack.
    def to_json(*_args)
      Oj.dump(name)
    end

    def custom?
      false
    end

    def state
      filename.present? ? READY_STATE : CREATED_STATE
    end

    private

    def validate_multiple_nil_stacks
      return unless stack.nil?

      errors.add(:stack, :unique) if Buildpack.exclude(guid:).where(name: name, stack: nil).present?
    end

    def validate_stack_change
      return if initial_value(:stack).nil?

      errors.add(:stack, :buildpack_cant_change_stacks) if column_changes.key?(:stack)
    end

    def validate_stack_existence
      return unless stack

      errors.add(:stack, :buildpack_stack_does_not_exist) if Stack.where(name: stack).empty?
    end
  end
end
