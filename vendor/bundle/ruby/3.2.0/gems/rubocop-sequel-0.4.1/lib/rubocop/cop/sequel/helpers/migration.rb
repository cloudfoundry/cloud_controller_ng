# frozen_string_literal: true

module RuboCop
  module Cop
    module Sequel
      module Helpers
        # Migration contains helper methods for detecting if a node is inside a `Sequel.migration` block
        module Migration
          extend NodePattern::Macros

          def_node_matcher :sequel_migration_block?, <<~MATCHER
            (block
              (send
                (const nil? :Sequel) :migration ...)
              ...)
          MATCHER

          def within_sequel_migration?(node)
            node.each_ancestor(:block).any? { |ancestor| sequel_migration_block?(ancestor) }
          end
        end
      end
    end
  end
end
