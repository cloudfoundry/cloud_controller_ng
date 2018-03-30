module RuboCop
  module Cop
    module Migration
      class RequirePrimaryKey < RuboCop::Cop::Cop
        # Require all newly created tables to have a primary key defined
        TABLE_CREATE_METHODS = %i{
          create_table
        }.freeze
        PRIMARY_KEY_WARNING = 'Please include a call to primary_key when creating a table.' +
          ' This is to ensure compatibility with clustered databases.'.freeze

        def on_block(node)
          return unless creating_table?(node)

          unless has_primary_key_call?(node) || has_vcap_migration_call?(node)
            add_offense(node, location: :expression, message: PRIMARY_KEY_WARNING)
          end
        end

        private

        def has_primary_key_call?(node)
          node.each_descendant(:send).any? { |n| n.method_name == :primary_key }
        end

        def has_vcap_migration_call?(node)
          node.each_descendant(:send).any? { |n| n.children[0]&.const_name == 'VCAP::Migration' && n.children[1] == :common }
        end

        def creating_table?(node)
          node.children[0].send_type? && TABLE_CREATE_METHODS.include?(node.children[0].method_name)
        end
      end
    end
  end
end
