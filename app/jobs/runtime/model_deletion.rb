module VCAP::CloudController
  module Jobs
    module Runtime
      class ModelDeletion < Struct.new(:model_class, :guid)

        def perform
          model = model_class.find(guid: guid)
          return if model.nil?
          model.destroy
        end

        def job_name
          :model_deletion
        end

        def max_attempts
          1
        end
      end
    end
  end
end
