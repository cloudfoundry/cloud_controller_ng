# frozen_string_literal: true

module RuboCop
  # RuboCop Sequel project namespace
  module Sequel
    PROJECT_ROOT = Pathname.new(__dir__).parent.parent.expand_path.freeze
    CONFIG_DEFAULT = PROJECT_ROOT.join('config', 'default.yml').freeze
    CONFIG = YAML.safe_load(CONFIG_DEFAULT.read).freeze

    private_constant(:CONFIG_DEFAULT, :PROJECT_ROOT)

    if ::RuboCop.const_defined?(:ConfigObsoletion)
      ::RuboCop::ConfigObsoletion.files << PROJECT_ROOT.join('config', 'obsoletion.yml')
    end
  end
end
