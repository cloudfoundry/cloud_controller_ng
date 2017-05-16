module VCAP::CloudController
  class Buildpack < Sequel::Model
    plugin :list

    export_attributes :name, :position, :enabled, :locked, :filename
    import_attributes :name, :position, :enabled, :locked, :filename, :key

    def self.list_admin_buildpacks
      exclude(key: nil).exclude(key: '').order(:position).all
    end

    def self.at_last_position
      where(position: max(:position)).first
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end

    def validate
      validates_unique :name
      validates_format(/\A(\w|\-)+\z/, :name, message: 'name can only contain alphanumeric characters')
    end

    def locked?
      !!locked
    end

    def enabled?
      !!enabled
    end

    def staging_message
      { buildpack_key: self.key }
    end

    # This is used in the serialization of apps to JSON. The buildpack object is left in the hash for the app, then the
    # JSON encoder calls to_json on the buildpack.
    def to_json
      MultiJson.dump name
    end

    def custom?
      false
    end
  end
end
