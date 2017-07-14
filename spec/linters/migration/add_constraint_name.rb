module RuboCop
  module Cop
    module Migration
      class AddConstraintName < RuboCop::Cop::Cop
        # Postgres and MySQL have different naming conventions, so if we need to remove them we cannot predict accurately what the constraint name would be.
        MSG = 'Please explicitly name your index or constraint.'.freeze
        CONSTRAINT_METHODS = %i{
          add_unique_constraint add_constraint add_foreign_key add_index add_primary_key add_full_text_index add_spatial_index
          unique_constraint constraint foreign_key index primary_key full_text_index spatial_index
        }.freeze
        COLUMN_ADDING_METHODS = %i{
          add_column column String Integer
        }.freeze

        def on_block(node)
          node.each_descendant(:send) do |send_node|
            method = method_name(send_node)
            next unless constraint_adding_method?(method) || column_adding_method?(method)

            opts = send_node.children.last
            missing_named_constraint = true

            if opts
              if constraint_adding_method?(method)
                missing_named_constraint = add_constraint_missing_name?(opts)
              elsif column_adding_method?(method)
                missing_named_constraint = add_column_missing_name?(opts)
              end
            end

            add_offense(send_node, :expression) if missing_named_constraint
          end
        end

        private

        def constraint_adding_method?(method)
          CONSTRAINT_METHODS.include?(method)
        end

        def column_adding_method?(method)
          COLUMN_ADDING_METHODS.include?(method)
        end

        def add_constraint_missing_name?(opts)
          return true unless opts.type == :hash

          opts.each_node(:pair) do |pair|
            return false if hash_key_type(pair) == :sym && hash_key_name(pair) == :name
          end

          true
        end

        def add_column_missing_name?(opts)
          return true if opts.type == :sym && %i{index primary_key unique}.include?(sym_opts_name(opts))

          needs_named_index             = false
          needs_named_primary_key       = false
          needs_named_unique_constraint = false

          opts.each_node(:pair) do |pair|
            next unless hash_key_type(pair) == :sym
            case hash_key_name(pair)
            when :index then needs_named_index = true
            when :primary_key then needs_named_primary_key = true
            when :unique then needs_named_unique_constraint = true
            end
          end

          opts.each_node(:pair) do |pair|
            next unless hash_key_type(pair) == :sym

            case hash_key_name(pair)
            when :name then needs_named_index = false
            when :primary_key_constraint_name then needs_named_primary_key = false
            when :unique_constraint_name then needs_named_unique_constraint = false
            end
          end

          [needs_named_index, needs_named_primary_key, needs_named_unique_constraint].any?
        end

        def method_name(node)
          node.children[1]
        end

        def hash_key_type(pair)
          pair.children[0].type
        end

        def hash_key_name(pair)
          pair.children[0].children[0]
        end

        def sym_opts_name(opts)
          opts.children[0]
        end
      end
    end
  end
end
