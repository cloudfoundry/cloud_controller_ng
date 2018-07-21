module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestParsers
        class ServicesPropertiesParser
          def parse(_, service_bindings, _)
            service_instance_names = service_bindings.map(&:service_instance_name)
            {services: alphabetize(service_instance_names).presence, }
          end

          def alphabetize(array)
            array.sort_by(&:downcase)
          end
        end
      end
    end
  end
end
