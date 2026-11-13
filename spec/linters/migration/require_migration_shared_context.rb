module RuboCop
  module Cop
    module Migration
      class RequireMigrationSharedContext < Base
        MSG = "Per-migration specs must include the 'migration' shared context " \
              "(include_context 'migration') so they use the shared setup and helpers " \
              '(run_migration, revert_migration, test_up_migration_idempotency, ' \
              'test_down_migration_idempotency). See spec/migrations/Readme.md for details.'.freeze

        def on_new_investigation
          return unless processed_source.ast
          return if includes_migration_context?

          add_offense(processed_source.ast)
        end

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
