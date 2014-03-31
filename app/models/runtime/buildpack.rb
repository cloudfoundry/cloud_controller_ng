module VCAP::CloudController
  class Buildpack < Sequel::Model

    export_attributes :name, :position, :enabled, :locked, :filename

    import_attributes :name, :key, :position, :enabled, :locked, :filename

    def self.list_admin_buildpacks
      exclude(:key => nil).exclude(:key => "").order(:position).all
    end

    def self.at_last_position
      where(position: max(:position)).first
    end

    def self.create(values = {}, &block)
      last = Buildpack.at_last_position

      if last
        db.transaction(savepoint: true) do
          last.lock!

          buildpack = new(values, &block)

          target_position = determine_position(buildpack, last)

          if target_position <= last.position
            shift_positions_up(target_position)
          end

          buildpack.update(position: target_position)
        end
      else
        super(values) do |instance|
          block.yield(instance) if block
          instance.position = 1
        end
      end
    end

    def self.update(obj, values = {})
      attrs = values.dup
      target_position = attrs.delete("position")
      db.transaction(savepoint: true) do
        obj.lock!
        obj.update_from_hash(attrs)
        if target_position
          target_position = 1 if target_position < 1
          obj.shift_to_position(target_position)
        end
      end
      obj
    end

    def after_destroy
      shift_positions_down()
      super
    end

    def staging_message
      { buildpack_key: self.key }
    end

    def validate
      validates_unique :name
      validates_format(/^(\w|\-)+$/, :name, message: "name can only contain alphanumeric characters")
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end

    def to_json
      Yajl::Encoder.encode name
    end


    def custom?
      false
    end

    def locked?
      self.locked
    end

    def shift_to_position(target_position)
      return if target_position == position
      target_position = 1 if target_position < 1

      db.transaction(savepoint: true) do
        last = Buildpack.at_last_position
        if last
          last.lock!
          last_position = last.position
          target_position = last_position if target_position > last_position
          shift_and_update_positions(target_position) if target_position != position
        else
          update(position: 1)
        end
      end
    end

    private

    def self.determine_position(buildpack, last)
      position = buildpack.position
      if !position || position > last.position
        position = last.position + 1
      elsif position < 1
        position = 1
      end
      position
    end

    def shift_positions_down
      Buildpack.for_update.where('position > ?', position).update(position: Sequel.-(:position, 1))
    end

    def self.shift_positions_up(position)
      for_update.where('position >= ?', position).update(position: Sequel.+(:position, 1))
    end

    def shift_and_update_positions(target_position)
      if target_position > position
        Buildpack.shift_positions_down_between(position, target_position)
      elsif target_position < position
        Buildpack.shift_positions_up_between(target_position, position)
      end

      update(position: target_position)
    end

    def self.shift_positions_up_between(low, high)
      for_update.where {position >= low}.and{position < high}.update(position: Sequel.+(:position, 1))
    end

    def self.shift_positions_down_between(low, high)
      for_update.where {position > low}.and{position <= high}.update(position: Sequel.-(:position, 1))
    end

  end
end
