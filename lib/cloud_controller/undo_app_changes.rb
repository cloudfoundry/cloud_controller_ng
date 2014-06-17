module VCAP::CloudController
  class UndoAppChanges
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def undo(changes)
      undo_start(changes)
      undo_scale(changes)
    end

    private

    def undo_start(changes)
      state = changes[:state]
      return false if state.nil? || state[1] != 'STARTED'
      update(changes, :state)
    end


    def undo_scale(changes)
      instances = changes[:instances]
      return false if instances.nil? || instances[0] >= instances[1]

      update(changes, :instances)
    end

    def update(changes, key)
      where_columns = app.pk_hash
      where_columns[key] = changes[key][1]
      where_columns[:updated_at] = changes[:updated_at][1]

      update_columns = { key => changes[key][0]}

      count = App.dataset.where(where_columns).update(update_columns)      
      app.refresh
      logger.warn("app.rollback.failed", guid: app.guid, self: app.inspect, to: update_columns) if count == 0

      return count == 1
    end

    def logger
       @logger ||= Steno.logger("cc.undo_app_changes")
    end
  end
end
