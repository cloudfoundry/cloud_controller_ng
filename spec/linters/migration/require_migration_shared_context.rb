require_relative 'migration_context'

module RuboCop
  module Cop
    module Migration
      class RequireMigrationSharedContext < Base
        include MigrationContext

        MSG = "Per-migration specs must include the 'migration' shared context " \
              "(include_context 'migration') so they use the shared setup and helpers " \
              '(run_migration, revert_migration, test_up_migration_idempotency, ' \
              'test_down_migration_idempotency). See spec/migrations/Readme.md for details.'.freeze

        def on_new_investigation
          return unless processed_source.ast
          return if includes_migration_context?

          add_offense(processed_source.ast)
        end
      end
    end
  end
end
