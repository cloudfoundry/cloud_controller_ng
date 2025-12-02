# frozen_string_literal: true

module RuboCop
  module Cop
    module Sequel
      # MigrationName looks for migration files named with a default name.
      class MigrationName < Base
        include RangeHelp

        MSG = 'Migration files should not use default name.'

        def on_new_investigation
          file_path = processed_source.buffer.name
          return if config.file_to_include?(file_path)

          return unless filename_bad?(file_path)

          location = source_range(processed_source.buffer, 1, 0)
          add_offense(location)
        end

        private

        def filename_bad?(path)
          basename = File.basename(path)
          basename =~ /#{cop_config.fetch('DefaultName', 'new_migration')}/
        end
      end
    end
  end
end
