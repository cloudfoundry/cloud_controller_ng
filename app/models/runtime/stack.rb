module VCAP::CloudController
  class Stack < Sequel::Model
    class MissingConfigFileError < StandardError; end
    class MissingDefaultStackError < StandardError; end

    one_to_many :apps

    plugin :serialization

    export_attributes :name, :description
    import_attributes :name, :description

    strip_attributes :name

    def validate
      validates_presence :name
      validates_unique :name
    end

    def before_destroy
      if apps.present?
        raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', 'app', 'stack')
      end
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
  end
end
