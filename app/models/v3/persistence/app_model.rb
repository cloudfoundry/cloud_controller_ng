module VCAP::CloudController
  class AppModel < Sequel::Model(:apps_v3)
    include Serializer
    APP_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze

    many_to_many :routes, join_table: :apps_v3_routes, left_key: :app_v3_id

    many_to_one :space, class: 'VCAP::CloudController::Space', key: :space_guid, primary_key: :guid, without_guid_generation: true
    one_to_many :processes, class: 'VCAP::CloudController::App', key: :app_guid, primary_key: :guid
    one_to_many :packages, class: 'VCAP::CloudController::PackageModel', key: :app_guid, primary_key: :guid
    one_to_many :droplets, class: 'VCAP::CloudController::DropletModel', key: :app_guid, primary_key: :guid

    encrypt :environment_variables, salt: :salt, column: :encrypted_environment_variables
    serializes_via_json :environment_variables

    def validate
      validates_presence :name
      validates_unique [:space_guid, :name]
      validates_format APP_NAME_REGEX, :name
      validate_environment_variables
    end

    def validate_environment_variables
      return unless environment_variables
      keys = environment_variables.keys
      keys.each do |key|
        key = key.to_s
        if key =~ /^CF_/i
          errors.add(:environment_variables, 'cannot start with CF_')
        elsif key =~ /^VCAP_/i
          errors.add(:environment_variables, 'cannot start with VCAP_')
        elsif key == 'PORT'
          errors.add(:environment_variables, 'cannot set PORT')
        end
      end
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
