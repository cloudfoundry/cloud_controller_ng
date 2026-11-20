require 'actions/space_delete'
require 'actions/label_delete'
require 'actions/annotation_delete'
require 'actions/organization_service_account_cleanup'

module VCAP::CloudController
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
        return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, account_errors.map(&:message).join("\n\n"))] unless account_errors.empty?

        domains_to_unshare = []
        org.private_domains.each do |private_domain|
          if private_domain.owning_organization == org
            errs << "Domain '#{private_domain.name}' is shared with other organizations. Unshare before deleting." if private_domain.shared_with_any_orgs?
          else
            domains_to_unshare << private_domain
          end
        end

        return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, errs.join("\n\n"))] unless errs.empty?

        Organization.db.transaction do
          unshare_private_domains(domains_to_unshare, org)
          org.destroy

          Repositories::OrganizationEventRepository.new.record_organization_delete_request(org, @user_audit_info, { recursive: true })
        end
      end

      []
    end

    def timeout_error(dataset)
      org_name = dataset.first.name
      CloudController::Errors::ApiError.new_from_details('OrganizationDeleteTimeout', org_name)
    end

    private

    def unshare_private_domains(domains_to_unshare, org_model)
      # find all private domains that are shared with this org
      # for each one, unshare the org

      domains_to_unshare.each do |domain|
        domain.remove_shared_organization(org_model)
      end
    end
  end
end
