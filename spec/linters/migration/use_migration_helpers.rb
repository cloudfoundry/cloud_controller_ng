module RuboCop
  module Cop
    module Migration
      class UseMigrationHelpers < Base
        MSG = 'Do not call Sequel::Migrator.run directly in a migration spec that includes ' \
              "the 'migration' shared context. " \
              'Use the provided helpers instead: run_migration, revert_migration, ' \
              'test_up_migration_idempotency, test_down_migration_idempotency. ' \
              'See spec/migrations/Readme.md for details.'.freeze

        HOOK_METHODS = %i[before after around].freeze

        def on_new_investigation
          return unless processed_source.ast
          return unless includes_migration_context?

          processed_source.ast.each_descendant(:send) do |node|
            next unless migrator_run_call?(node)
            next if inside_hook_block?(node)

            add_offense(node)
          end
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

        def inside_hook_block?(node)
          node.each_ancestor(:block).any? { |block| HOOK_METHODS.include?(block.send_node.method_name) }
        end

        def migrator_run_call?(node)
          node.method_name == :run &&
            node.receiver&.const_type? &&
            ['Migrator', 'Sequel::Migrator'].include?(node.receiver.const_name)
        end
      end
    end
  end
end
