module VCAP::CloudController
  module Diego
    module ReporterMixins
      private

      def nanoseconds_to_seconds(time)
        (time / 1e9).to_i
      end

      def fill_unreported_instances_with_down_instances(reported_instances, process, flat:)
        process.instances.times do |i|
          next if reported_instances[i]

          down_instance = { state: VCAP::CloudController::Diego::LRP_DOWN }
          down_instance.merge!(flat ? { uptime: 0 } : { stats: { uptime: 0 } })

          reported_instances[i] = down_instance
        end

        reported_instances
      end
    end
  end
end
