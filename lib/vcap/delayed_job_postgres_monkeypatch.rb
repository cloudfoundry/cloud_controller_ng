# TODO: Can this be removed since we are no longer using ActiveRecord for Delayed Job?
#
# This monkey patch removes the PostgreSQL case since it is incompatible with PostgreSQL 9.0.3,
# which is the version we are using in the on-premise installation deployed by Tempest. Once the
# Tempest deployment upgrades to PostgreSQL 9.1 or above, we can delete this file entirely.

#module Delayed
#  module Backend
#    module ActiveRecord
#
#      class Job < ::ActiveRecord::Base
#        def self.reserve(worker, max_run_time = Worker.max_run_time)
#          ready_scope = self.ready_to_run(worker.name, max_run_time)
#
#          ready_scope = ready_scope.where('priority >= ?', Worker.min_priority) if Worker.min_priority
#          ready_scope = ready_scope.where('priority <= ?', Worker.max_priority) if Worker.max_priority
#          ready_scope = ready_scope.where(:queue => Worker.queues) if Worker.queues.any?
#          ready_scope = ready_scope.by_priority
#
#          now = self.db_time_now
#
#          case self.connection.adapter_name
#            #when "PostgreSQL"
#            #  quoted_table_name = self.connection.quote_table_name(self.table_name)
#            #  subquery_sql      = ready_scope.limit(1).lock(true).select('id').to_sql
#            #  reserved          = self.find_by_sql(["UPDATE #{quoted_table_name} SET locked_at = ?, locked_by = ? WHERE id IN (#{subquery_sql}) RETURNING *", now, worker.name])
#            #  reserved[0]
#          when "MySQL", "Mysql2"
#            count = ready_scope.limit(1).update_all(:locked_at => now, :locked_by => worker.name)
#            return nil if count == 0
#            self.where(:locked_at => now, :locked_by => worker.name).first
#          else
#            ready_scope.limit(worker.read_ahead).detect do |job|
#              count = ready_scope.where(:id => job.id).update_all(:locked_at => now, :locked_by => worker.name)
#              count == 1 && job.reload
#            end
#          end
#        end
#      end
#    end
#  end
#end
