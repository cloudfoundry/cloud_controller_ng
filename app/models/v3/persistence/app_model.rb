module VCAP::CloudController
  class AppModel < Sequel::Model(:apps_v3)
    APP_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze

    one_to_many :processes, class: 'VCAP::CloudController::App', key: :app_guid, primary_key: :guid

    def validate
      validates_presence :name
      validates_unique [:space_guid, :name]
      validates_format APP_NAME_REGEX, :name
      validates_space_exists(send(:space_guid))
    end

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

    private

    def validates_space_exists(space_guid)
      errors.add(:space_guid, "space does not exist") if Space.where(guid: space_guid).count <= 0
    end
  end
end
