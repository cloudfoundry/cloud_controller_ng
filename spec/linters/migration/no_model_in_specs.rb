module RuboCop
  module Cop
    module Migration
      class NoModelInSpecs < RuboCop::Cop::Base
        MSG = 'Do not use model classes in migration specs. ' \
              'Use raw Sequel operations (e.g. db[:table].insert) instead. ' \
              'See spec/migrations/Readme.md for details.'.freeze

        def on_new_investigation
          @model_let_names = Set.new
          return unless processed_source.ast

          processed_source.ast.each_descendant(:block) do |node|
            next unless %i[let let!].include?(node.send_node&.method_name)

            let_name_node = node.send_node.first_argument
            next unless let_name_node&.sym_type?

            body = node.body
            next unless body

            # let(:foo) { SomeModel } or let(:foo) { VCAP::CloudController::SomeModel }
            inner = body.begin_type? ? body.children.last : body
            @model_let_names << let_name_node.value if model_const_node?(inner)
          end
        end

        def on_send(node)
          add_offense(node) if model_receiver?(node.receiver)
        end

        private

        def model_receiver?(receiver)
          return false unless receiver

          return model_const_node?(receiver) if receiver.const_type?
          return @model_let_names.include?(receiver.method_name) if receiver.send_type?

          false
        end

        def model_const_node?(node)
          return false unless node&.const_type?

          model_class_name?(node.const_name.to_s)
        end

        def model_class_name?(name)
          name.end_with?('Model') && name != 'Sequel::Model'
        end
      end
    end
  end
end
