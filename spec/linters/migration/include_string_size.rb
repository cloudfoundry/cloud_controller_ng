module RuboCop
  module Cop
    module Migration
      class IncludeStringSize < RuboCop::Cop::Cop
        # Postgres and MySQL have different size limits on String and TEXT fields
        # MySQL: `String` is `varchar(255)`, `String, text: true` has a max size of 16_000 for UTF8 encoded DBs
        # Postgres: `String` and `String, text: true` are `TEXT` and has a max size of ~1GB
        # This linter ensures we have a consistent size limit across all DBs which enables users to
        #   transfer from Postgres to MySQL without truncating tables.
        COLUMN_ADDING_METHODS = %i{
          add_column set_column_type String
        }.freeze
        STRING_SIZE_WARNING = 'Please specify an explicit size for String columns.' +
          ' `size: 255` is a good size for small strings, `size: 16_000` is the maximum for UTF8 strings.'.freeze
        STRING_TEXT_WARNING = 'Please use `size: 16_000` (max UTF8 size) instead of `text: true`.'.freeze

        def on_block(node)
          node.each_descendant(:send) do |inner_node|
            method = inner_node.method_name
            next unless adding_column?(method)

            has_string = method == :String || has_const_child(inner_node, 'String')
            next unless has_string

            has_text = node_has_hash_key?(inner_node, :text, &:truthy_literal?)

            if has_text
              add_offense(inner_node, :expression, STRING_TEXT_WARNING)
              next
            end

            has_size = node_has_hash_key?(inner_node, :size)

            add_offense(inner_node, :expression, STRING_SIZE_WARNING) unless has_size
          end
        end

        private

        def node_has_hash_key?(node, name)
          node.each_descendant(:hash).any? {
            |hash| hash.each_pair.any? { |pair|
              pair.key.children[0] == name && (!block_given? || yield(pair.value))
            }
          }
        end

        def has_const_child(node, value)
          node.each_descendant(:const).any? { |n| n.const_name == value }
        end

        def adding_column?(method)
          COLUMN_ADDING_METHODS.include?(method)
        end
      end
    end
  end
end
