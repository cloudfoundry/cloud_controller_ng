require 'scientist'

module VCAP::CloudController
  module Perm
    class Experiment
      attr_reader :name
      include Scientist::Experiment

      def initialize(name:, perm_enabled:, query_enabled:)
        @name = name
        @perm_enabled = perm_enabled
        @query_enabled = query_enabled
      end

      def enabled?
        @perm_enabled && @query_enabled
      end

      def publish(result)
        if result.matched?
          logger.debug(
            "matched",
            {
              context: @_scientist_context,
              control: observation_payload(result.control),
              candidate: observation_payload(result.candidates.first),
            }
          )
        else
          logger.info(
            "mismatched",
            {
              context: @_scientist_context,
              control: observation_payload(result.control),
              candidate: observation_payload(result.candidates.first),
            })
        end
      end

      private

      def logger
        @logger ||= Steno.logger("science.#{name}")
      end

      def observation_payload(observation)
        if observation.raised?
          {
            :exception => observation.exception.class,
            :message   => observation.exception.message,
            :backtrace => observation.exception.backtrace
          }
        else
          {
            :value => observation.cleaned_value
          }
        end
      end
    end
  end
end
