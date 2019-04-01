require 'scientist'

module VCAP::CloudController
  module Science
    class Experiment < Scientist::Default
      include Scientist::Experiment

      def initialize(name:, statsd_client:, enabled:)
        super(name)
        @statsd_client = statsd_client
        @enabled = enabled
      end

      def enabled?
        @enabled
      end

      def publish(result)
        success = 0

        if result.matched?
          success = 1

          logger.debug(
            'matched',
            {
              context: @_scientist_context,
              control: observation_payload(result.control),
              candidate: observation_payload(result.candidates.first),
            }
          )

          statsd_client.timing("cc.perm.experiment.#{name}.timing.match.control", result.control.duration * 1000)
          statsd_client.timing("cc.perm.experiment.#{name}.timing.match.candidate", result.candidates.first.duration * 1000)
        else
          logger.info(
            'mismatched',
            {
              context: @_scientist_context,
              control: observation_payload(result.control),
              candidate: observation_payload(result.candidates.first),
            })

          statsd_client.timing("cc.perm.experiment.#{name}.timing.mismatch.control", result.control.duration * 1000)
          statsd_client.timing("cc.perm.experiment.#{name}.timing.mismatch.candidate", result.candidates.first.duration * 1000)
        end

        statsd_client.gauge("cc.perm.experiment.#{name}.match", success)
        statsd_client.gauge('cc.perm.experiment.match', success)
      end

      private

      attr_reader :statsd_client, :enabled

      def logger
        @logger ||= Steno.logger("science.#{name}")
      end

      def observation_payload(observation)
        if observation.raised?
          {
            exception: observation.exception.class,
            message: observation.exception.message,
            backtrace: observation.exception.backtrace
          }
        else
          {
            value: observation.cleaned_value
          }
        end
      end
    end
  end
end
