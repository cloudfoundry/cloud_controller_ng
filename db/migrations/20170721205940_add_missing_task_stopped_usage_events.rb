require 'securerandom'

Sequel.migration do
  change do
    task_started_events = self[:app_usage_events].where(state: 'TASK_STARTED')
    task_started_events.each do |started_event|
      guid = started_event[:task_guid]
      next if self[:app_usage_events].where(state: 'TASK_STOPPED', task_guid: guid).any?
      next if self[:tasks].where(guid: guid).any?

      cloned_event_hash = started_event.clone
      cloned_event_hash.delete(:id)
      cloned_event_hash.merge!(guid: SecureRandom.uuid, state: 'TASK_STOPPED', created_at: Sequel.function(:NOW))

      self[:app_usage_events].insert(cloned_event_hash)
    end
  end
end
