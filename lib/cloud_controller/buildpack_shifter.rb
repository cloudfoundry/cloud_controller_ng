module VCAP::CloudController
  class BuildpackShifter
    def shift_positions_down(buildpack)
      Buildpack.for_update.where { position > buildpack.position }.update(position: Sequel.-(:position, 1))
    end

    def shift_positions_down_between(low, high)
      Buildpack.where { position > low }.and { position <= high }.update(position: Sequel.-(:position, 1))
    end

    def shift_positions_up_between(low, high)
      Buildpack.where { position >= low }.and { position < high }.update(position: Sequel.+(:position, 1))
    end

    def shift_positions_up(new_position)
      Buildpack.for_update.where { position >= new_position }.update(position: Sequel.+(:position, 1))
    end
  end
end
