module VCAP::CloudController
  class BuildpackPositioner
    def initialize
      @db = Buildpack.db
    end

    def create(values, &block)
      last = Buildpack.at_last_position

      @db.transaction(savepoint: true) do
        last.lock!

        buildpack = Buildpack.new(values, &block)

        target_position = determine_position(buildpack, last)

        if target_position <= last.position
          shift_positions_up(target_position)
        end

        buildpack.update(position: target_position)
      end
    end

    def update(obj, values={})
      attrs = values.dup
      target_position = attrs.delete("position")
      @db.transaction(savepoint: true) do
        obj.lock!

        obj.update_from_hash(attrs)
        if target_position
          target_position = 1 if target_position < 1
          shift_to_position(obj, target_position)
        end
      end
      obj
    end

    def shift_positions_down(buildpack)
      Buildpack.for_update.where('position > ?', buildpack.position).update(position: Sequel.-(:position, 1))
    end

    private

    def shift_to_position(buildpack, target_position)
      return if target_position == buildpack.position

      target_position = 1 if target_position < 1
      last = Buildpack.at_last_position
      last.lock!

      last_position = last.position
      target_position = last_position if target_position > last_position
      shift_and_update_positions(buildpack, target_position) if target_position != buildpack.position
    end

    def shift_and_update_positions(buildpack, target_position)
      if target_position > buildpack.position
        shift_positions_down_between(buildpack.position, target_position)
      elsif target_position < buildpack.position
        shift_positions_up_between(target_position, buildpack.position)
      end

      buildpack.update(position: target_position)
    end

    def determine_position(buildpack, last)
      position = buildpack.position
      if !position || position > last.position
        position = last.position + 1
      elsif position < 1
        position = 1
      end
      position
    end

    def shift_positions_down_between(low, high)
      Buildpack.for_update.where { position > low }.and { position <= high }.update(position: Sequel.-(:position, 1))
    end

    def shift_positions_up_between(low, high)
      Buildpack.for_update.where { position >= low }.and { position < high }.update(position: Sequel.+(:position, 1))
    end

    def shift_positions_up(position)
      Buildpack.for_update.where("position >= ?", position).update(position: Sequel.+(:position, 1))
    end
  end
end
