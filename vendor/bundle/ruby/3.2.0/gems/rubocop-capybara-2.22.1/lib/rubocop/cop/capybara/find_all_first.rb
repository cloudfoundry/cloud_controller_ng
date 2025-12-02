# frozen_string_literal: true

module RuboCop
  module Cop
    module Capybara
      # Enforces use of `first` instead of `all` with `first` or `[0]`.
      #
      # @example
      #
      #   # bad
      #   all('a').first
      #   all('a')[0]
      #   find('a', match: :first)
      #   all('a', match: :first)
      #
      #   # good
      #   first('a')
      #
      class FindAllFirst < ::RuboCop::Cop::Base
        extend AutoCorrector
        include RangeHelp

        MSG = 'Use `first(%<selector>s)`.'
        RESTRICT_ON_SEND = %i[all find].freeze

        # @!method find_all_first?(node)
        def_node_matcher :find_all_first?, <<~PATTERN
          {
            (send (send _ :all _ ...) :first)
            (send (send _ :all _ ...) :[] (int 0))
          }
        PATTERN

        # @!method include_match_first?(node)
        def_node_matcher :include_match_first?, <<~PATTERN
          (send _ {:find :all} _ $(hash <(pair (sym :match) (sym :first)) ...>))
        PATTERN

        def on_send(node)
          on_all_first(node)
          on_match_first(node)
        end

        private

        def on_all_first(node)
          return unless (parent = node.parent)
          return unless find_all_first?(parent)

          range = range_between(node.loc.selector.begin_pos,
                                parent.loc.selector.end_pos)
          selector = node.arguments.map(&:source).join(', ')
          add_offense(range,
                      message: format(MSG, selector: selector)) do |corrector|
            corrector.replace(range, "first(#{selector})")
          end
        end

        def on_match_first(node)
          include_match_first?(node) do |hash|
            selector = ([node.first_argument.source] + replaced_hash(hash))
              .join(', ')
            add_offense(node,
                        message: format(MSG, selector: selector)) do |corrector|
              corrector.replace(node, "first(#{selector})")
            end
          end
        end

        def replaced_hash(hash)
          hash.child_nodes.flat_map(&:source).reject do |arg|
            arg == 'match: :first'
          end
        end
      end
    end
  end
end
