require 'set'

module RuboCop
  module Cop
    class MatchRequiresWithIncludes < RuboCop::Cop::Cop
      REQ_FOR_INCLUDES = {
        'VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers' =>
          'presenters/mixins/metadata_presentation_helpers',
        'SubResource' => 'controllers/v3/mixins/sub_resource',
      }.freeze

      def initialize(*args)
        @requires = Set.new
        super
      end

      def on_send(node)
        return unless node.send_type?

        if node.children[1] == :require
          @requires << node.child_nodes[0].children[0]
          return
        end
        return if node.children[1] != :include

        included_module = extract_values(node.child_nodes[0]).join('::')
        req = REQ_FOR_INCLUDES[included_module]
        if req && !@requires.member?(req)
          add_offense(node, location: :expression, message: "Included '#{included_module}' but need to require '#{req}'")
        end
      end

      private

      def extract_values(node)
        return [] if node.nil? || node.type != :const

        extract_values(node.children[0]) + [node.children[1]]
      end
    end
  end
end
