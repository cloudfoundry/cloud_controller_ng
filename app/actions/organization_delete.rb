require 'actions/space_delete'
require 'actions/label_delete'
require 'actions/annotation_delete'

module VCAP::CloudController
  class OrganizationDelete
    def initialize(space_deleter, user_audit_info)
      @space_deleter = space_deleter
      @user_audit_info = user_audit_info
    end

    def delete(org_dataset)
      org_dataset.each do |org|
        errs = @space_deleter.delete(org.spaces_dataset)
        unless errs.empty?
          error_message = errs.map(&:message).join("\n\n")
          return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, error_message)]
        end

        domains_to_unshare = []
        org.private_domains.each do |private_domain|
          if private_domain.owning_organization == org
            if private_domain.shared_with_any_orgs?
              errs << "Domain '#{private_domain.name}' is shared with other organizations. Unshare before deleting."
            end
          else
            domains_to_unshare << private_domain
          end
        end

        unless errs.empty?
          return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, errs.join("\n\n"))]
        end

        Organization.db.transaction do
          unshare_private_domains(domains_to_unshare, org)
          org.destroy

          Repositories::OrganizationEventRepository.new.record_organization_delete_request(org, @user_audit_info, { recursive: true })
        end
      end
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
