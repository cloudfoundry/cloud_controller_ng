module VCAP::CloudController::Models
  class CrashEvent < Sequel::Model
    many_to_one :app

    export_attributes :app_guid, :instance_guid, :instance_index, :exit_status, :exit_description, :timestamp
    import_attributes :app_guid, :instance_guid, :instance_index, :exit_status, :exit_description, :timestamp

    def validate
      validates_presence :app
      validates_presence :instance_guid
      validates_presence :instance_index
      validates_presence :exit_status
      validates_presence :timestamp
    end

    def self.find_by_space(space_guid, options = {})
      space = Space[:guid => space_guid]
      ds = CrashEvent
        .join(:apps, :id => q(:crash_events, :app_id))
        .where(:space_id => space.id)
        .select(q(:crash_events, :id), :timestamp, :exit_description, :exit_status)
      filter_by_timestamps(ds, options[:start_time], options[:end_time])
    end

    def self.find_by_org(org_guid, options = {})
      org = Organization[:guid => org_guid]
      ds = CrashEvent
        .join(:apps, :id => q(:crash_events, :app_id))
        .join(:spaces, :id => q(:apps, :space_id))
        .where(q(:spaces, :id) => org.id)
        .select(q(:crash_events, :id), :timestamp, :exit_description, :exit_status)
      filter_by_timestamps(ds, options[:start_time], options[:end_time])
    end

    private

    def self.filter_by_timestamps(ds, start_time, end_time)
      ds = ds.where("timestamp >= ?", start_time) if start_time
      ds = ds.where('timestamp <= ?', end_time) if end_time
      ds
    end

    def self.q(table, column)
      Sequel.qualify(table, column)
    end
  end
end