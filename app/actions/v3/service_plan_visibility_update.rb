module VCAP::CloudController
  module V3
    class ServicePlanVisibilityUpdate
      class Error < ::StandardError
      end

      class UnprocessableRequest < ::StandardError
      end

      def update(service_plan, message, append_organizations: false)
        type = message.type
        requested_org_guids = message.organizations&.map { |o| o[:guid] } || []

        unprocessable!("cannot update plans with visibility type 'space'") if space?(service_plan)

        service_plan.db.transaction do
          service_plan.lock!

          service_plan.public = public?(type)

          if org?(type)
            update_service_plan_visibilities(service_plan, requested_org_guids, append_organizations)
          else
            service_plan.remove_all_service_plan_visibilities
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

      def update_service_plan_visibilities(service_plan, requested_org_guids, append_organizations)
        visibility_objects = service_plan.service_plan_visibilities
        current_org_guids = visibility_objects.map(&:organization_guid)

        unless append_organizations
          org_guids_not_in_request = (current_org_guids - requested_org_guids)
          visibility_ids_to_delete = visibility_objects.map { |v| v.id if org_guids_not_in_request.include?(v.organization_guid) }

          ServicePlanVisibility.where(id: visibility_ids_to_delete).delete
        end

        org_guids_to_add = (requested_org_guids - current_org_guids)
        org_guids_to_add.each do |org_guid|
          service_plan.add_service_plan_visibility(organization_guid: org_guid)
        end
      end

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
