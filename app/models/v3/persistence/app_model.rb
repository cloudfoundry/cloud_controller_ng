module VCAP::CloudController
  class AppModel < Sequel::Model(:apps_v3)
    APP_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze

    many_to_many :routes, join_table: :apps_v3_routes, left_key: :app_v3_id

    many_to_one :space, class: 'VCAP::CloudController::Space', key: :space_guid, primary_key: :guid, without_guid_generation: true
    one_to_many :processes, class: 'VCAP::CloudController::App', key: :app_guid, primary_key: :guid
    one_to_many :packages, class: 'VCAP::CloudController::PackageModel', key: :app_guid, primary_key: :guid
    one_to_many :droplets, class: 'VCAP::CloudController::DropletModel', key: :app_guid, primary_key: :guid

    def validate
      validates_presence :name
      validates_unique [:space_guid, :name]
      validates_format APP_NAME_REGEX, :name
    end

    def self.user_visible(user)
      dataset.where(user_visibility_filter(user))
    end

    def self.user_visibility_filter(user)
      Sequel.or([
        [:space_guid, user.spaces_dataset.select(:guid)],
        [:space_guid, user.managed_spaces_dataset.select(:guid)],
        [:space_guid, user.audited_spaces_dataset.select(:guid)],
        [:space_guid, user.managed_organizations_dataset.join(
          :spaces, spaces__organization_id: :organizations__id
        ).select(:spaces__guid)],
      ])
    end
  end
end
