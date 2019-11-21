module VCAP::CloudController
  class RoleGuidPopulate
    class Error < StandardError
    end

    class << self
      def populate
        Role.db.transaction do
          populate_missing_guids OrganizationUser
          populate_missing_guids OrganizationAuditor
          populate_missing_guids OrganizationManager
          populate_missing_guids OrganizationBillingManager
          populate_missing_guids SpaceAuditor
          populate_missing_guids SpaceDeveloper
          populate_missing_guids SpaceManager
        end
      rescue Sequel::ValidationFailed => e
        raise Error.new(e.message)
      end

      private

      def populate_missing_guids(model)
        model.where(role_guid: nil).each do |role|
          role.update(guid: SecureRandom.uuid)
        end
      end
    end
  end
end
