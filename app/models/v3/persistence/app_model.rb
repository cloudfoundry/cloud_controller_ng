module VCAP::CloudController
  class AppModel < Sequel::Model(:apps_v3)
    one_to_many :processes, class: 'VCAP::CloudController::App', key: :app_guid, primary_key: :guid

    def self.user_visible(user)
      dataset.where(Sequel.or([
        [:space_guid, user.spaces_dataset.select(:guid)],
        [:space_guid, user.managed_spaces_dataset.select(:guid)],
        [:space_guid, user.audited_spaces_dataset.select(:guid)],
        [:space_guid, user.managed_organizations_dataset.join(
          :spaces, spaces__organization_id: :organizations__id
        ).select(:spaces__guid)],
      ]))
    end
  end
end
