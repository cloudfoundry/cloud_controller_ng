module RuboCop
  module Cop
    module Migration
      class NoModelInSpecs < RuboCop::Cop::Base
        MSG = 'Do not use model classes in migration specs. ' \
              'Use raw Sequel operations (e.g. db[:table].insert) instead. ' \
              'See spec/migrations/Readme.md for details.'.freeze

        def on_send(node)
          add_offense(node) if model_receiver?(node.receiver)
        end

        private

        def model_receiver?(receiver)
          return false unless receiver
          return false unless receiver.const_type?

          name = receiver.const_name.to_s
          name.end_with?('Model') && name != 'Sequel::Model'
        end
      end
    end
  end
end
