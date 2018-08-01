module VCAP::CloudController
  class UndoAppChanges
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def undo(previous_changes)
      undo_changes = {}
      changes = previous_changes.dup
      state_changes = changes.delete(:state)
      undo_start(state_changes, undo_changes) if state_changes
      undo_scale(changes, undo_changes)
      undo_updated_at(changes, undo_changes)
      save_app(changes, undo_changes) if undo_changes.any?
    end

    private

    def undo_start(state_changes, undo_changes)
      return if state_changes[1] != 'STARTED'
      undo_changes[:state] = state_changes[0]
    end

    def undo_scale(changes, undo_changes)
      instances = changes[:instances]
      return if instances.nil? || instances[0] >= instances[1]
      undo_changes[:instances] = instances[0]
    end

    def undo_updated_at(changes, undo_changes)
      undo_changes[:updated_at] = changes[:updated_at][0] if changes[:updated_at]
    end

    def save_app(changes, undo_changes)
      finder = app.pk_hash.merge(date_trunc_clause(changes[:updated_at]))
      count = App.dataset.where(finder).update(undo_changes)
      app.refresh
      logger.warn('app.rollback.failed', guid: app.guid, self: app.inspect, to: undo_changes) if count == 0
      count == 1
    end

    def logger
      @logger ||= Steno.logger('cc.undo_app_changes')
    end

    def date_trunc_clause(updated_at)
      return {} unless updated_at && updated_at[1]
      if App.db.database_type == :postgres
        { Sequel.lit("date_trunc('second', updated_at)") => updated_at[1].change(usec: 0) }
      elsif App.db.database_type == :mysql
        { Sequel.lit('UNIX_TIMESTAMP(updated_at)') => updated_at[1].to_i }
      else
        {}
      end
    end
  end
end
