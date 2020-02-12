module VCAP::CloudController
  module V3
    class ServicePlanVisibilityUpdate
      class Error < ::StandardError
      end

      def update(service_plan, message)
        params = {}
        params[:type] = message.type if message.requested?(:type)

        error!("cannot update plans with visibility type 'space'") if service_plan.visibility_type == VCAP::CloudController::ServicePlanVisibilityTypes::SPACE
        error!(message.errors.full_messages[0]) unless message.valid?

        service_plan.db.transaction do
          service_plan.lock!
          service_plan.public = params[:type] == VCAP::CloudController::ServicePlanVisibilityTypes::PUBLIC

          service_plan.save
        end

        service_plan
      rescue Sequel::ValidationFailed => e
        error!(e.message)
      end

      private

      def error!(message)
        raise Error.new(message)
      end
    end
  end
end
