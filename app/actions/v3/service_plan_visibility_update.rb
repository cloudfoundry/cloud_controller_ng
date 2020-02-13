module VCAP::CloudController
  module V3
    class ServicePlanVisibilityUpdate
      class Error < ::StandardError
      end

      class UnprocessableRequest < ::StandardError
      end

      def update(service_plan, message, append_organizations: false)
        type = message.type if message.requested?(:type)
        org_guids = message.organizations if message.requested?(:organizations)

        unprocessable!("cannot update plans with visibility type 'space'") if space?(service_plan)
        error!(message.errors.full_messages[0]) unless message.valid?

        service_plan.db.transaction do
          service_plan.lock!

          service_plan.public = public?(type)

          service_plan.service_plan_visibilities.each(&:destroy) unless org?(type) && append_organizations

          unless org_guids.nil?
            current_visibilities = service_plan.service_plan_visibilities.map(&:organization_guid)
            (org_guids - current_visibilities).each do |org_guid|
              service_plan.add_service_plan_visibility(organization_guid: org_guid)
            end
          end

          service_plan.save
        end

        service_plan.reload
      rescue Sequel::ValidationFailed => e
        error!(e.message)
      rescue CloudController::Errors::ApiError => e
        error!(e.message.gsub('VCAP::CloudController::', ''))
      end

      private

      def error!(message)
        raise Error.new(message)
      end

      def unprocessable!(message)
        raise UnprocessableRequest.new(message)
      end

      def space?(service_plan)
        service_plan.visibility_type == VCAP::CloudController::ServicePlanVisibilityTypes::SPACE
      end

      def org?(type)
        type == VCAP::CloudController::ServicePlanVisibilityTypes::ORGANIZATION
      end

      def public?(type)
        type == VCAP::CloudController::ServicePlanVisibilityTypes::PUBLIC
      end
    end
  end
end
