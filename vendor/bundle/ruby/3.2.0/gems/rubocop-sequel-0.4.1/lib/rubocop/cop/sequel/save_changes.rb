# frozen_string_literal: true

module RuboCop
  module Cop
    module Sequel
      # SaveChanges promotes the use of save_changes.
      class SaveChanges < Base
        extend AutoCorrector

        MSG = 'Use `Sequel::Model#save_changes` instead of `Sequel::Model#save`.'
        RESTRICT_ON_SEND = %i[save].freeze

        def_node_matcher :model_save?, <<-MATCHER
          (send _ :save)
        MATCHER

        def on_send(node)
          return unless model_save?(node)

          range = node.loc.selector

          add_offense(range, message: MSG) do |corrector|
            corrector.replace(range, 'save_changes')
          end
        end
      end
    end
  end
end
