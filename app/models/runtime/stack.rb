require 'models/helpers/process_types'

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
      class:             'VCAP::CloudController::ProcessModel',
      join_table:        BuildpackLifecycleDataModel.table_name,
      left_primary_key:  :name, left_key: :stack,
      right_primary_key: :app_guid, right_key: :app_guid,
      conditions:        { type: ProcessTypes::WEB }

    one_to_many :labels, class: 'VCAP::CloudController::StackLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::StackAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    plugin :serialization

    export_attributes :name, :description, :build_rootfs_image, :run_rootfs_image
    import_attributes :name, :description, :build_rootfs_image, :run_rootfs_image

    strip_attributes :name

    def validate
      validates_presence :name
      validates_unique :name
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
      super || self.name
    end

    def run_rootfs_image
      super || self.name
    end

    def self.configure(file_path)
      @config_file = if file_path
                       ConfigFile.new(file_path)
                     end
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
        unless found_stack
          raise MissingDefaultStackError.new("Default stack with name '#{@config_file.default}' not found")
        end
      end
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end

    def self.populate_from_hash(hash)
      stack = find(name: hash['name'])
      if stack
        stack.set(hash)
        if stack.modified?
          Steno.logger('cc.stack').warn('stack.populate.collision', hash)
        end
      else
        create(hash.slice('name', 'description', 'build_rootfs_image', 'run_rootfs_image'))
      end
    end

    class ConfigFile
      def initialize(file_path)
        @hash = YAMLConfig.safe_load_file(file_path).tap do |h|
          Schema.validate(h)
        end
      end

      def stacks
        @hash['stacks']
      end

      def default
        @hash['default']
      end

      Schema = Membrane::SchemaParser.parse do
        {
          'default' => String,
          'stacks'  => [{
            'name'        => String,
            'description' => String,
            optional('build_rootfs_image') => String,
            optional('run_rootfs_image') => String,
          }]
        }
      end
    end
  end
end
