module VCAP::CloudController
  class CheckStacks
    attr_reader :config

    def initialize(config, db)
      @config = config
      @stack_config = VCAP::CloudController::Stack::ConfigFile.new(config.get(:stacks_file))
      @db = db
    end

    def validate_stacks
      deprecated_stacks = @stack_config.deprecated_stacks
      return if deprecated_stacks.blank?

      deprecated_stacks.each { |stack| validate_stack(stack) }
    end

    private

    def validate_stack(deprecated_stack)
      configured_stacks = @stack_config.stacks
      deprecated_stack_in_config = (configured_stacks.find { |stack| stack['name'] == deprecated_stack }).present?

      return if deprecated_stack_in_config

      deprecated_stack_in_db = false
      @db.fetch('SELECT * FROM stacks WHERE name LIKE ? ', deprecated_stack) do |_row|
        deprecated_stack_in_db = true
      end
      raise "rake task 'stack_check' failed, stack '#{deprecated_stack}' not supported" if deprecated_stack_in_db
    end
  end
end
