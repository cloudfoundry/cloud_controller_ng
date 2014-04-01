require "cloud_controller/buildpack_positioner"
require "cloud_controller/buildpack_shifter"

module VCAP::CloudController
  class Buildpack < Sequel::Model
    export_attributes :name, :position, :enabled, :locked, :filename
    import_attributes :name, :position, :enabled, :locked, :filename, :key

    def self.list_admin_buildpacks
      exclude(:key => nil).exclude(:key => "").order(:position).all
    end

    def self.at_last_position
      where(position: max(:position)).first
    end

    def self.locked_last_position
      last = at_last_position
      last.lock!
      last.position
    end

    def self.create(new_attributes = {}, &block)
      new_attributes = new_attributes.symbolize_keys # Unfortunately we aren't consistent with whether we use
                                                     # strings or symbols for keys so we need to be defensive.

      if Buildpack.at_last_position.nil?
        super(new_attributes) do |instance|
          block.yield(instance) if block
          instance.position = 1
        end
      else
        db.transaction(savepoint: true) do
          buildpack = Buildpack.new(new_attributes, &block)
          positioner = BuildpackPositioner.new
          normalized_position = positioner.position_for_create(buildpack.position)

          buildpack.position = normalized_position
          buildpack.save
        end
      end
    end

    def self.update(buildpack, updated_attributes = {})
      updated_attributes = updated_attributes.symbolize_keys # Unfortunately we aren't consistent with whether we use
                                                             # strings or symbols for keys so we need to be defensive.
      db.transaction(savepoint: true) do
        buildpack.lock!

        normalized_attributes = if updated_attributes.has_key?(:position)
          positioner = BuildpackPositioner.new
          normalized_position = positioner.position_for_update(buildpack.position, updated_attributes[:position])
          updated_attributes.merge(position: normalized_position)
        else
          updated_attributes
        end

        buildpack.update_from_hash(normalized_attributes)
      end

      buildpack
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
      validates_format(/^(\w|\-)+$/, :name, message: "name can only contain alphanumeric characters")
    end

    def locked?
      !!locked
    end

    def staging_message
      {buildpack_key: self.key}
    end

    def to_json
      Yajl::Encoder.encode name
    end

    def custom?
      false
    end
  end
end
