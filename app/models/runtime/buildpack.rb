require 'cloud_controller/buildpack_positioner'
require 'cloud_controller/buildpack_shifter'

module VCAP::CloudController
  class Buildpack < Sequel::Model
    export_attributes :name, :position, :enabled, :locked, :filename
    import_attributes :name, :position, :enabled, :locked, :filename, :key

    def self.list_admin_buildpacks
      exclude(key: nil).exclude(key: '').order(:position).all
    end

    def self.at_last_position
      where(position: max(:position)).first
    end

    def before_save
      if new? || column_changed?(:position)
        Locking[name: 'buildpacks'].lock!
        positioner = BuildpackPositioner.new
        self.position = if new?
                          if Buildpack.at_last_position.nil?
                            1
                          else
                            positioner.position_for_create(position)
                          end
                        else
                          positioner.position_for_update(initial_value(:position), position)
                        end
      end
      super
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end

    def after_destroy
      super

      shifter = BuildpackShifter.new
      shifter.shift_positions_down(self)
    end

    def validate
      validates_unique :name
      validates_format(/^(\w|\-)+$/, :name, message: 'name can only contain alphanumeric characters')
    end

    def locked?
      !!locked
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
