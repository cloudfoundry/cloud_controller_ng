module RuboCop
  module Cop
    module Migration
      module MigrationContext
        private

        def includes_migration_context?
          processed_source.ast.each_descendant(:send).any? { |node| migration_shared_context?(node) }
        end

        def migration_shared_context?(node)
          node.method_name == :include_context &&
            node.receiver.nil? &&
            node.first_argument&.str_type? &&
            node.first_argument.value == 'migration'
        end
      end
    end
  end
end
