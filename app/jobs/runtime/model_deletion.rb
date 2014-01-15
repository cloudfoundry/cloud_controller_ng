module VCAP::CloudController
  module Jobs
    module Runtime
      class ModelDeletion < Struct.new(:model_class, :guid)
        include VCAP::CloudController::TimedJob

        def perform
          Timeout.timeout max_run_time(:model_deletion) do
            model = model_class.find(guid: guid)
            return if model.nil?
            model.destroy
          end
        end

        def max_attempts
          1
        end
      end
    end
  end
end
