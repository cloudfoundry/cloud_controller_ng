# frozen_string_literal: true

module Spec
  module Helpers
    module Migration
      extend CopHelper

      def inspect_source_within_migration(source, file = nil)
        migration_wrapped_source = <<~SOURCE
          Sequel.migration do
            #{source}
          end
        SOURCE

        inspect_source(migration_wrapped_source, file)
      end
    end
  end
end
