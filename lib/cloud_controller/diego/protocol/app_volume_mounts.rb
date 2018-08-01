module VCAP::CloudController
  module Diego
    class Protocol
      class AppVolumeMounts
        def initialize(app)
          @app = app
        end

        def as_json(_options={})
          @app.service_bindings.map(&:volume_mounts).reject(&:nil?).flatten
        end
      end
    end
  end
end
