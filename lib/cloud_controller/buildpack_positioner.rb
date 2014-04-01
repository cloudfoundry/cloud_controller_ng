module VCAP::CloudController
  class BuildpackPositioner
    def initialize
      @db = Buildpack.db
    end

    def create(new_attributes, &block)
      @db.transaction(savepoint: true) do
        buildpack = Buildpack.new(new_attributes, &block)
        desired_position = buildpack.position

        last_position = Buildpack.locked_last_position
        normalized_position = normalize_position_for_add(desired_position, last_position)

        if normalized_position <= last_position
          shift_positions_up(normalized_position)
        end

        buildpack.position = normalized_position
        buildpack.save
      end
    end

    def normalize(buildpack, desired_position)
      current_position = buildpack.position
      last_position = Buildpack.locked_last_position
      normalized_position = normalize_position_for_move(desired_position, last_position)

      unless normalized_position == current_position
        shift_and_update_positions(current_position, normalized_position)
      end

      normalized_position
    end

    def shift_positions_down(buildpack)
      Buildpack.for_update.where('position > ?', buildpack.position).update(position: Sequel.-(:position, 1))
    end

    private

    def normalize_position_for_add(target_position, last_position)
      case
        when target_position.nil?
          last_position + 1
        when target_position > last_position
          last_position + 1
        when target_position < 1
          1
        else
          target_position
      end
    end

    def normalize_position_for_move(target_position, last_position)
      case
        when target_position > last_position
          last_position
        when target_position < 1
          1
        else
          target_position
      end
    end

    def shift_and_update_positions(buildpack_position, target_position)
      if target_position > buildpack_position
        shift_positions_down_between(buildpack_position, target_position)
      elsif target_position < buildpack_position
        shift_positions_up_between(target_position, buildpack_position)
      end
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
