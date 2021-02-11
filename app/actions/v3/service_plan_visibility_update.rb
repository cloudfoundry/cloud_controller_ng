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
        if append_organizations
          append_service_plan_visibilities(service_plan, requested_org_guids)
        else
          replace_service_plan_visibilities(service_plan, requested_org_guids)
        end
      end

      def append_service_plan_visibilities(service_plan, requested_org_guids)
        requested_org_guids.each do |org_guid|
          unless already_has_visibility?(service_plan, org_guid)
            service_plan.add_service_plan_visibility(organization_guid: org_guid)
          end
        end
      end

      def replace_service_plan_visibilities(service_plan, requested_org_guids)
        service_plan.remove_all_service_plan_visibilities
        requested_org_guids.each do |org_guid|
          service_plan.add_service_plan_visibility(organization_guid: org_guid)
        end
      end

      def already_has_visibility?(service_plan, org_guid)
        service_plan.service_plan_visibilities_dataset.
          join(:organizations, id: Sequel[:service_plan_visibilities][:organization_id]).
          where(Sequel[:organizations][:guid] =~ org_guid).
          any?
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
