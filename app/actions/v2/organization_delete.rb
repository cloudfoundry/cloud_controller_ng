require 'actions/space_delete'
require 'actions/label_delete'
require 'actions/annotation_delete'
require 'actions/organization_service_account_cleanup'

module VCAP::CloudController
  module V2
    class OrganizationDelete
      include OrganizationServiceAccountCleanup

      def initialize(space_deleter, user_audit_info)
        @space_deleter = space_deleter
        @user_audit_info = user_audit_info
      end

      def delete(org_dataset)
        org_dataset.each do |org|
          shared_errors = shared_domain_errors(org)
          return shared_errors unless shared_errors.empty?

          mark_deleting_for_account_cleanup(org)
          errs = @space_deleter.delete(org.spaces_dataset)
          unless errs.empty?
            error_message = errs.map(&:message).join("\n\n")
            return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, error_message)]
          end

          account_errors = delete_service_accounts(org)
          unless account_errors.empty?
            return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, account_errors.map(&:message).join("\n\n"))]
          end

          Organization.db.transaction do
            org.destroy
          end
        end
        []
      end

      def timeout_error(dataset)
        org_name = dataset.first.name
        CloudController::Errors::ApiError.new_from_details('OrganizationDeleteTimeout', org_name)
      end
    end
  end
end
