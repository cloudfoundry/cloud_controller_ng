# frozen_string_literal: true

module RuboCop
  module Cop
    module Sequel
      # PartialConstraint looks for missed usage of partial indexes.
      class PartialConstraint < Base
        include Helpers::Migration

        MSG = "Constraint can't be partial, use where argument with index"
        RESTRICT_ON_SEND = %i[add_unique_constraint].freeze

        def_node_matcher :add_partial_constraint?, <<-MATCHER
          (send _ :add_unique_constraint ... (hash (pair (sym :where) _)))
        MATCHER

        def on_send(node)
          return unless add_partial_constraint?(node)
          return unless within_sequel_migration?(node)

          add_offense(node.loc.selector, message: MSG)
        end
      end
    end
  end
end
