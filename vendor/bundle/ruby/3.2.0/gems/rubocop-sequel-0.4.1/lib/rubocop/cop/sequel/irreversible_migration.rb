# frozen_string_literal: true

module RuboCop
  module Cop
    module Sequel
      # IrreversibleMigration looks for methods inside a `change` block that cannot be reversed.
      class IrreversibleMigration < Base
        include Helpers::Migration

        # https://sequel.jeremyevans.net/rdoc/files/doc/migration_rdoc.html#label-A+Basic+Migration
        VALID_CHANGE_METHODS = %i[
          create_table
          create_join_table
          create_view
          add_column
          add_index
          rename_column
          rename_table
          alter_table
          add_column
          add_constraint
          add_foreign_key
          add_primary_key
          add_index
          add_full_text_index
          add_spatial_index
          rename_column
          set_column_allow_null
        ].freeze

        MSG = 'Using "%<name>s" inside a "change" block may cause an irreversible migration. Use "up" & "down" instead.'
        PRIMARY_KEY_MSG = 'Avoid using "add_primary_key" with an array argument inside a "change" block.'

        def on_block(node)
          return unless node.method_name == :change
          return unless within_sequel_migration?(node)

          body = node.body
          return unless body

          body.each_node(:send) { |child_node| validate_node(child_node) }
        end

        private

        def validate_node(node)
          return if within_create_table_block?(node)

          return if part_of_method_call?(node)

          add_offense(node.loc.selector, message: format(MSG, name: node.method_name)) unless valid_change_method?(node)

          add_offense(node.loc.selector, message: PRIMARY_KEY_MSG) if invalid_primary_key_method?(node)
        end

        def valid_change_method?(node)
          VALID_CHANGE_METHODS.include?(node.method_name)
        end

        def invalid_primary_key_method?(node)
          return false unless node.method_name == :add_primary_key

          node.arguments.any?(&:array_type?)
        end

        def within_create_table_block?(node)
          return true if node.method_name == :create_table

          node.each_ancestor(:block).any? do |ancestor|
            ancestor.method_name == :create_table
          end
        end

        def part_of_method_call?(node)
          node.each_ancestor(:send).count.positive?
        end
      end
    end
  end
end
