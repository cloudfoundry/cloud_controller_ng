module Fog
  module Google
    class Compute
      class Mock
        def insert_target_instance(_target_name, _zone, _target_instance = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def insert_target_instance(target_name, zone, target_instance = {})
          zone = zone.split("/")[-1] if zone.start_with? "http"
          @compute.insert_target_instance(
            @project, zone,
            ::Google::Apis::ComputeV1::TargetInstance.new(
              **target_instance.merge(name: target_name)
            )
          )
        end
      end
    end
  end
end
