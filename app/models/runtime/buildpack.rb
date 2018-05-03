module VCAP::CloudController
  class Buildpack < Sequel::Model
    plugin :list

    export_attributes :name, :stack, :position, :enabled, :locked, :filename
    import_attributes :name, :stack, :position, :enabled, :locked, :filename, :key

    def self.list_admin_buildpacks(stack_name=nil)
      scoped = exclude(key: nil).exclude(key: '')
      if stack_name.present?
        scoped = scoped.filter(Sequel.or([
          [:stack, stack_name],
          [:stack, nil]
        ]))
      end
      scoped.order(:position).all
    end

    def self.at_last_position
      where(position: max(:position)).first
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end

    def validate
      validates_unique [:name, :stack]
      validates_format(/\A(\w|\-)+\z/, :name, message: 'name can only contain alphanumeric characters')

      validate_stack_existence
      validate_stack_change
    end

    def locked?
      !!locked
    end

    def enabled?
      !!enabled
    end

    def staging_message
      { buildpack_key: self.key }
    end

    # This is used in the serialization of apps to JSON. The buildpack object is left in the hash for the app, then the
    # JSON encoder calls to_json on the buildpack.
    def to_json
      MultiJson.dump name
    end

    def custom?
      false
    end

    private

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
