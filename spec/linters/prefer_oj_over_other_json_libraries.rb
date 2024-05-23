module RuboCop
  module Cop
    class PreferOjOverOtherJsonLibraries < RuboCop::Cop::Cop
      MSG = 'Avoid using `%s`, prefer `Oj` instead'.freeze

      def_node_matcher :other_json_lib?, <<-PATTERN
        (send                                               # send node
          {
            $(const nil? {:MultiJson :JSON})                # constant equals 'MultiJson' or 'JSON'
                                                            #   or
            (const $(const nil? :Yajl) {:Encoder :Parser})  # parent constant + constant equal 'Yajl::Encoder' or 'Yajl::Parser'
          }
          _                                                 # any method name
          ...                                               # any arguments
        )
      PATTERN

      def on_send(node)
        other_json_lib?(node) { |lib| add_offense(node, message: sprintf(MSG, lib.const_name)) }
      end
    end
  end
end
