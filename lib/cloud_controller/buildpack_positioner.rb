require 'cloud_controller/buildpack_positioner'

module VCAP::CloudController
  class BuildpackPositioner
    def initialize
      @shifter = BuildpackShifter.new
    end

    def position_for_create(desired_position)
      last_position = Buildpack.at_last_position.position
      normalized_position = normalize_position_for_add(desired_position, last_position)

      if normalized_position <= last_position
        @shifter.shift_positions_up(normalized_position)
      end
      normalized_position
    end

    def position_for_update(current_position, desired_position)
      last_position = Buildpack.at_last_position.position
      normalized_position = normalize_position_for_move(desired_position, last_position)

      if normalized_position != current_position
        if normalized_position > current_position
          @shifter.shift_positions_down_between(current_position, normalized_position)
        elsif normalized_position < current_position
          @shifter.shift_positions_up_between(normalized_position, current_position)
        end
      end

      normalized_position
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
  end
end
