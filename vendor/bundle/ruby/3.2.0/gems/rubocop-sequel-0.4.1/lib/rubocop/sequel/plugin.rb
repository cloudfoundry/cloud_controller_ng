# frozen_string_literal: true

require 'lint_roller'

module RuboCop
  module Sequel
    # A plugin that integrates rubocop-sequel with RuboCop's plugin system.
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: 'rubocop-sequel',
          version: Version::STRING,
          homepage: 'https://github.com/rubocop/rubocop-sequel',
          description: 'Code style checking for Sequel.'
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: Pathname.new(__dir__).join('../../../config/default.yml')
        )
      end
    end
  end
end
