require 'models/helpers/process_types'
require 'models/helpers/stack_config_file'
require 'models/helpers/stack_states'

module VCAP::CloudController
  class Stack < Sequel::Model
    class MissingConfigFileError < StandardError
    end
    class MissingDefaultStackError < StandardError
    end
    class AppsStillPresentError < StandardError
    end

    # NOTE: that "apps" here returns processes for v2 meta-reasons
    many_to_many :apps,
                 class: 'VCAP::CloudController::ProcessModel',
                 join_table: BuildpackLifecycleDataModel.table_name,
                 left_primary_key: :name, left_key: :stack,
                 right_primary_key: :app_guid, right_key: :app_guid,
                 conditions: { type: ProcessTypes::WEB }

    one_to_many :labels, class: 'VCAP::CloudController::StackLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::StackAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    plugin :serialization

    export_attributes :name, :description, :build_rootfs_image, :run_rootfs_image
    import_attributes :name, :description, :build_rootfs_image, :run_rootfs_image

    strip_attributes :name

    def around_save
      yield
    rescue Sequel::UniqueConstraintViolation => e
      raise e unless e.message.include?('stacks_name_index')

      errors.add(:name, :unique)
      raise validation_failed_error
    end

    def validate
      validates_presence :name
      validates_unique :name
      validates_includes StackStates::VALID_STATES, :state, allow_nil: true
    end

    def before_destroy
      raise AppsStillPresentError.new if apps.present?

      super
    end

    def default?
      self == Stack.default
    rescue MissingDefaultStackError
      false
    end

    def build_rootfs_image
      super || name
    end

    def run_rootfs_image
      super || name
    end

    def self.configure(file_path)
      @config_file = (StackConfigFile.new(file_path) if file_path)
    end

    def self.populate
      raise MissingConfigFileError unless @config_file

      @config_file.stacks.each do |stack_hash|
        populate_from_hash(stack_hash)
      end
    end

    def self.default
      raise MissingConfigFileError unless @config_file

      self[name: @config_file.default].tap do |found_stack|
        raise MissingDefaultStackError.new("Default stack with name '#{@config_file.default}' not found") unless found_stack
      end
    end

    def self.user_visibility_filter(_user)
      full_dataset_filter
    end

    def self.populate_from_hash(hash)
      stack = find(name: hash['name'])
      if stack
        stack.set(hash)
        Steno.logger('cc.stack').warn('stack.populate.collision', hash) if stack.modified?
      else
        create(hash.slice('name', 'description', 'build_rootfs_image', 'run_rootfs_image'))
      end
    end

    def active?
      state == StackStates::STACK_ACTIVE
    end

    def deprecated?
      state == StackStates::STACK_DEPRECATED
    end

    def restricted?
      state == StackStates::STACK_RESTRICTED
    end

    def disabled?
      state == StackStates::STACK_DISABLED
    end

    def can_stage_new_app?
      !restricted? && !disabled?
    end

    def can_restage_apps?
      !disabled?
    end
  end
end
