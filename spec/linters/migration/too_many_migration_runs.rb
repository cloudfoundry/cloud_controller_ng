module RuboCop
  module Cop
    module Migration
      class TooManyMigrationRuns < Base
        def on_new_investigation
          return unless processed_source.ast

          definitions = extract_migrator_definitions
          call_count = count_migrator_calls(definitions)

          return unless call_count > 4

          add_offense(processed_source.ast,
                      message: "Too many migration runs (#{call_count}). Combine tests to reduce migrations. See spec/migrations/README.md for further guidance.")
        end

        private

        def extract_migrator_definitions
          definitions = {
            subject_names: [],
            method_names: [],
            let_names: [],
            before_after_blocks: Set.new
          }

          # Single pass through the AST to collect all definitions
          processed_source.ast.each_descendant(:def, :block) do |node|
            case node.type
            when :def
              extract_migrator_method(node, definitions[:method_names])
            when :block
              extract_block_definitions(node, definitions)
            end
          end

          definitions
        end

        def extract_migrator_method(node, method_names)
          return unless contains_migrator_run?(node)

          method_names << node.method_name
        end

        def extract_block_definitions(node, definitions)
          return unless node.send_node

          method_name = node.send_node.method_name

          case method_name
          when :subject
            extract_named_migrator(node, definitions[:subject_names])
          when :let, :let!
            extract_named_migrator(node, definitions[:let_names])
          when :before, :after, :around
            definitions[:before_after_blocks].add(node.object_id) if contains_migrator_run?(node)
          end
        end

        def extract_named_migrator(node, names)
          return unless contains_migrator_run?(node)

          first_arg = node.send_node.first_argument
          names << first_arg.value if first_arg&.sym_type?
        end

        def count_migrator_calls(definitions)
          call_count = 0

          # Single pass through send nodes to count all migration calls
          processed_source.ast.each_descendant(:send) do |node|
            next unless migration_call?(node, definitions)

            call_count += 1
          end

          call_count
        end

        def migration_call?(node, definitions)
          in_before_after_block = node.each_ancestor(:block).any? do |ancestor|
            definitions[:before_after_blocks].include?(ancestor.object_id)
          end

          if in_before_after_block
            # Count direct Migrator.run calls inside before/after/around blocks
            migrator_run_call?(node)
          else
            # Count direct calls (not in definitions) or helper invocations
            direct_migrator_call?(node) || helper_migration_call?(node, definitions)
          end
        end

        def direct_migrator_call?(node)
          return false unless migrator_run_call?(node)

          !inside_definition?(node)
        end

        def migrator_run_call?(node)
          return false unless node.method_name == :run

          receiver = node.receiver
          return false unless receiver

          # Check for Sequel::Migrator.run or just Migrator.run
          if receiver.const_type?
            receiver_name = receiver.const_name
            return ['Migrator', 'Sequel::Migrator'].include?(receiver_name)
          end

          false
        end

        def helper_migration_call?(node, definitions)
          method = node.method_name
          definitions[:subject_names].include?(method) ||
            definitions[:let_names].include?(method) ||
            definitions[:method_names].include?(method)
        end

        def contains_migrator_run?(node)
          node.each_descendant(:send).any? { |send_node| migrator_run_call?(send_node) }
        end

        def inside_definition?(node)
          node.each_ancestor(:def, :block).any? do |ancestor|
            case ancestor.type
            when :def
              contains_migrator_run?(ancestor)
            when :block
              next false unless ancestor.send_node

              method = ancestor.send_node.method_name
              if %i[subject let let!].include?(method)
                contains_migrator_run?(ancestor)
              else
                %i[before after around].include?(method)
              end
            end
          end
        end
      end
    end
  end
end
