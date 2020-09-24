module VCAP::CloudController::Presenters::Mixins
  module LastOperationHelper
    def last_operation(resource)
      last_operation = resource.try(:last_operation)

      if last_operation
        last_operation.to_hash
      else
        # Bindings created using V2 may not have a last operation, so we make
        # a best attempt so that the output JSON can be parsed consistently
        {
          type: 'create',
          state: 'succeeded',
          description: '',
          created_at: resource.try(:created_at),
          updated_at: resource.try(:updated_at),
        }
      end
    end
  end
end
