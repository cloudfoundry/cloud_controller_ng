require 'actions/service_account_provision'
require 'repositories/service_account_event_repository'

module VCAP::CloudController
  module OrganizationServiceAccountCleanup
    private

    def shared_domain_errors(org)
      return [] unless ServiceAccountModel.where(organization_id: org.id).any?

      domains = org.owned_private_domains_dataset.all.select(&:shared_with_any_orgs?)
      return [] if domains.empty?

      details = domains.map { |domain| "Domain '#{domain.name}' is shared with other organizations. Unshare before deleting." }.join("\n")
      [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, details)]
    end

    def mark_deleting_for_account_cleanup(org)
      return unless ServiceAccountModel.where(organization_id: org.id).any?

      org.db.transaction do
        org.lock!
        org.update(status: Organization::DELETING)
      end
    end

    def delete_service_accounts(org)
      accounts = ServiceAccountModel.where(organization_id: org.id).order(:guid).all
      return [] if accounts.empty?

      accounts.each_with_object([]) do |account, errors|
        locally_deleted = false
        account.db.transaction do
          account.lock!
          if PollableJobModel.where(resource_guid: account.guid, resource_type: 'service_account', state: %w[PROCESSING POLLING]).any?
            raise ServiceAccountProvision::Conflict.new('service account operation is already in progress')
          end

          if account.status == 'reserved' && !account.in_use?
            Repositories::ServiceAccountEventRepository.record(account, 'delete', @user_audit_info, { recursive: true })
            account.destroy
            locally_deleted = true
          else
            account.update(enabled: false, status: 'deleting')
          end
        end
        next if locally_deleted

        Repositories::ServiceAccountEventRepository.record(account, 'delete', @user_audit_info, { recursive: true })
        CloudController::DependencyLocator.instance.service_account_provisioner.deprovision(account, delete: true)
      rescue StandardError => e
        errors << e
      end
    end
  end
end
