module RuboCop
  module Cop
    module Migration
      class TooManyMigrationRuns < Base
        MSG = 'Too many migration runs (%d). Combine tests to reduce migrations. See spec/migrations/README.md for further guidance.'.freeze
        MAX_CALLS = 4

        def on_new_investigation
          calls = 0
          migrator_subject_names = []
          migrator_method_names = []
          migrator_let_names = []
          migrator_before_after_blocks = Set.new

          extract_migrator_definitions(migrator_subject_names, migrator_method_names,
                                       migrator_let_names, migrator_before_after_blocks)

          count_migrator_calls(calls, migrator_subject_names, migrator_method_names,
                               migrator_let_names, migrator_before_after_blocks)
        end

        def extract_migrator_definitions(subject_names, method_names, let_names, before_after_blocks)
          processed_source.ast.each_descendant(:def) do |node|
            method_name = extract_migrator_method_name(node)
            method_names << method_name if method_name
          end

          processed_source.ast.each_descendant(:block) do |node|
            subject_name = extract_migrator_subject_name(node)
            subject_names << subject_name if subject_name

            let_name = extract_migrator_let_name(node)
            let_names << let_name if let_name

            before_after_blocks.add(node.object_id) if is_before_after_around_with_migrator?(node)
          end
        end

        def count_migrator_calls(_calls, subjects, methods, lets, before_after_blocks)
          call_count = count_before_after_migrations(before_after_blocks)
          call_count += count_send_node_migrations(subjects, methods, lets, before_after_blocks)

          add_offense(processed_source.ast, message: sprintf(MSG, call_count)) if call_count > MAX_CALLS
        end

        def count_before_after_migrations(before_after_blocks)
          call_count = 0
          processed_source.ast.each_descendant(:block) do |node|
            call_count += count_direct_migrations_in_node(node) if before_after_blocks.include?(node.object_id)
          end
          call_count
        end

        def count_send_node_migrations(subjects, methods, lets, before_after_blocks)
          call_count = 0
          processed_source.ast.each_descendant(:send) do |node|
            next if node.each_ancestor(:block).any? { |a| before_after_blocks.include?(a.object_id) }

            call_count += count_migration_call(node, subjects, methods, lets)
          end
          call_count
        end

        def count_migration_call(node, subjects, methods, lets)
          return 1 if direct_migrator_call?(node)
          return 1 if helper_migration_call?(node, subjects, methods, lets)

          0
        end

        def direct_migrator_call?(node)
          return false unless node.method_name == :run && node.receiver&.source&.include?('Migrator')

          !inside_definition?(node)
        end

        def helper_migration_call?(node, subjects, methods, lets)
          subjects.include?(node.method_name) ||
            lets.include?(node.method_name) ||
            methods.include?(node.method_name)
        end

        private

        def extract_migrator_method_name(node)
          return nil unless node.type == :def
          return nil unless node.source.include?('Sequel::Migrator.run')

          node.method_name
        end

        def extract_migrator_subject_name(node)
          return nil unless node.send_node.method_name == :subject
          return nil unless node.source.include?('Sequel::Migrator.run')

          first_arg = node.send_node.first_argument
          first_arg&.sym_type? ? first_arg.value : nil
        end

        def extract_migrator_let_name(node)
          return nil unless %i[let let!].include?(node.send_node.method_name)
          return nil unless node.source.include?('Sequel::Migrator.run')

          first_arg = node.send_node.first_argument
          first_arg&.sym_type? ? first_arg.value : nil
        end

        def is_before_after_around_with_migrator?(node)
          return false unless node.send_node
          return false unless %i[before after around].include?(node.send_node.method_name)

          node.source.include?('Sequel::Migrator.run')
        end

        def count_direct_migrations_in_node(node)
          count = 0
          node.each_descendant(:send) do |descendant|
            count += 1 if descendant.method_name == :run && descendant.receiver&.source&.include?('Migrator')
          end
          count
        end

        def inside_definition?(node)
          node.each_ancestor(:def).any? { |a| a.source.include?('Sequel::Migrator.run') } ||
            node.each_ancestor(:block).any? do |a|
              %i[subject let let!].include?(a.send_node&.method_name) && a.source.include?('Sequel::Migrator.run')
            end ||
            node.each_ancestor(:block).any? do |a|
              %i[before after around].include?(a.send_node&.method_name)
            end
        end
      end
    end
  end
end
