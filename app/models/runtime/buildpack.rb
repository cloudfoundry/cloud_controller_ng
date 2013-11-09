module VCAP::CloudController
  class Buildpack < Sequel::Model

    export_attributes :name, :position, :enabled

    import_attributes :name, :key, :position, :enabled

    def self.list_admin_buildpacks
      results = exclude(:key => nil).exclude(:key => "").order(:position).all
      index_of_first_prioritized_position = results.find_index { |result| result.position > 0 }

      if index_of_first_prioritized_position
        results = results[index_of_first_prioritized_position..-1] + results.take(index_of_first_prioritized_position)
      end

      results
    end

    def self.at_last_position
      where(position: max(:position)).first
    end

    def self.create(values = {}, &block)
      last = Buildpack.at_last_position

      if last
        db.transaction(savepoint: true) do
          last.lock!
          last_position = last.position

          buildpack = new(values, &block)

          if !buildpack.position || buildpack.position >= last_position
            buildpack.position = last_position + 1
          end

          buildpack.shift_and_update_positions(last_position, buildpack.position)
          buildpack
        end
      else
        super(values.merge(position: 1), &block)
      end
    end

    def shift_to_position(target_position)
      return if target_position == position

      db.transaction(savepoint: true) do
        last = Buildpack.at_last_position
        if last
          last.lock!
          last_position = last.position
          target_position = last_position if target_position >= last_position
          shift_and_update_positions(last_position, target_position) if target_position != position
        else
          update(position: 1)
        end
      end
    end

    def staging_message
      { buildpack_key: self.key }
    end

    def validate
      validates_unique :name
      validates_format(/^(\w|\-)+$/, :name, :message => "name can only contain alphanumeric characters")
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end

    def to_json
      %Q("#{name}")
    end

    def shift_and_update_positions(last_position, target_position)
      if target_position == 0
        Buildpack.shift_positions_up_from(position)
      elsif target_position < last_position
        Buildpack.shift_positions_down_from(target_position)
      elsif target_position >= position
        Buildpack.shift_positions_up_from(position)
      end

      update(position: target_position)
    end

    private

    def self.for_update_lower_than(target_position)
      for_update.where { position >= target_position }
    end

    def self.shift_positions_down_from(target_position)
      for_update_lower_than(target_position).update(position: Sequel.+(:position, 1))
    end

    def self.shift_positions_up_from(target_position)
      for_update_lower_than(target_position).update(position: Sequel.-(:position, 1))
    end
  end
end
