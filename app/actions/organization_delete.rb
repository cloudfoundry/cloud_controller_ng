require 'actions/space_delete'

module VCAP::CloudController
  class OrganizationDelete
    def self.for_organization(org)
      new({ guid: org.guid }, SecurityContext.current_user, SecurityContext.current_user_email)
    end

    def initialize(dataset_opts, user, user_email)
      @dataset_opts = dataset_opts
      @user = user
      @user_email = user_email
    end

    def delete
      org_dataset = Organization.where(dataset_opts)
      org_dataset.each do |org|
        SpaceDelete.for_organization(org).delete
      end

      org_dataset.destroy
    end

    private

    attr_reader :dataset_opts, :user, :user_email
  end
end
