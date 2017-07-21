module RuboCop
  module Cop
    module Migration
      class IncludeStringSize < RuboCop::Cop::Cop
        # # Postgres and MySQL have different naming conventions, so if we need to remove them we cannot predict accurately what the constraint name would be.
        MSG                   = 'Please explicitly set your string size.'.freeze
        COLUMN_ADDING_METHODS = %i{
          add_column set_column_type String
        }.freeze

        def on_block(node)
          node.each_descendant(:send) do |inner_node|
            method = method_name(inner_node)
            next unless adding_column?(method)

            children = hash_children(inner_node)
            has_size = children.any? { |hash| hash_has_key?(hash, :size) }

            add_offense(inner_node, :expression) unless has_size
          end
        end

        private

        def hash_children(node)
          node.children.find_all { |n| n.class == RuboCop::AST::HashNode }
        end

        def adding_column?(method)
          COLUMN_ADDING_METHODS.include?(method)
        end

        def method_name(node)
          node.children[1]
        end

        def hash_key_name(pair)
          pair.children[0]
        end

        def hash_has_key?(hash, key)
          hash.keys.any? { |pair| hash_key_name(pair) == key }
        end
      end
    end
  end
end
