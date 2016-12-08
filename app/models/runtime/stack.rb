module VCAP::CloudController
  class Stack < Sequel::Model
    class MissingConfigFileError < StandardError; end
    class MissingDefaultStackError < StandardError; end
    class AssociationError < RuntimeError; end

    STACK_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/
    SHARED_STACK_CONDITION = { is_private: nil }.freeze

    dataset_module do
      def shared_stacks
        filter(SHARED_STACK_CONDITION)
      end

      def private_stacks
        filter(Sequel.~(SHARED_STACK_CONDITION))
      end
    end

    many_to_many :apps, join_table: BuildpackLifecycleDataModel.table_name,
                        left_primary_key: :name, left_key: :stack,
                        right_primary_key: :app_guid, right_key: :app_guid,
                        conditions: { type: 'web' }
    many_to_many(
      :organizations,
      class: 'VCAP::CloudController::Organization',
      join_table: 'organizations_private_stacks',
      left_key: :private_stack_id,
      right_key: :organization_id,
      before_add: :validate_add_organization
    )
    many_to_many(
      :spaces,
      class: 'VCAP::CloudController::Space',
      join_table: 'spaces_private_stacks',
      left_key: :private_stack_id,
      right_key: :space_id,
      before_add: :validate_add_space
    )

    plugin :serialization

    export_attributes :name, :description, :is_private
    import_attributes :name, :description, :is_private

    strip_attributes :name

    def validate
      validates_presence :name
      validates_unique :name
      validates_format STACK_NAME_REGEX, :name
      validate_change_privateness
    end

    def before_destroy
      if apps.present?
        raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'app', 'stack')
      end
    end

    def private?
      is_private
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
        create(hash.slice('name', 'description'))
      end
    end

    class ConfigFile
      def initialize(file_path)
        @hash = YAML.load_file(file_path).tap do |h|
          Schema.validate(h)
        end
      end

      def stacks
        @hash['stacks']
      end

      def default
        @hash['default']
      end

      Schema = Membrane::SchemaParser.parse {{
        'default' => String,
        'stacks' => [{
          'name' => String,
          'description' => String,
        }]
      }}
    end

    private

    def validate_add_organization(organization)
      return if is_private && !organization.suspended?
      raise AssociationError.new
    end

    def validate_add_space(space)
      return if is_private && !space.organization.suspended? && organizations.include?(space.organization)
      raise AssociationError.new
    end

    def validate_change_privateness
      return if self.new?
      raise CloudController::Errors::ApiError.new_from_details('StackInvalid', 'attribute `is_private` cannnot be changed') if self.modified?(:is_private)
    end
  end
end
