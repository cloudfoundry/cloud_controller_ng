require 'scientist'

module VCAP::CloudController
  module Perm
    class Experiment
      include Scientist::Experiment

      def initialize(name:, enabled:)
        @name = name
        @enabled = enabled
      end

      def enabled?
        @enabled
      end
    end
  end
end
