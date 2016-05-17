module VCAP::CloudController
  module Diego
    class Protocol
      class AppVolumeMounts
        def initialize(app)
          @app = app
        end

        def as_json(_options={})
          @app.service_bindings.map(&:volume_mounts).reject(&:nil?).flat_map(&method(:translate_volume_mounts))
        end

        private

        def translate_volume_mounts(volume_mounts)
          volume_mounts.map do |mount|
            {
              'driver'         => mount['private']['driver'],
              'volume_id'      => mount['private']['group_id'],
              'container_path' => mount['container_path'],
              'mode'           => map_mode(mount['mode']),
              'config'         => Base64.encode64(mount['private']['config']),
            }
          end
        end

        MODE_MAP = {
          'r'  => 0,
          'rw' => 1,
          'wr' => 1
        }.freeze

        def map_mode(mode)
          MODE_MAP[mode.downcase]
        end
      end
    end
  end
end
