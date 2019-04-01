module VCAP::CloudController
  module Diego
    module ReporterMixins
      private

      def nanoseconds_to_seconds(time)
        (time / 1e9).to_i
      end

      def fill_unreported_instances_with_down_instances(reported_instances, process)
        process.instances.times do |i|
          unless reported_instances[i]
            reported_instances[i] = {
              state:  'DOWN',
              uptime: 0,
            }
          end
        end

        reported_instances
      end
    end
  end
end
