Sequel.migration do
  change do
    events_to_backfill = self[:app_usage_events].
                         select_all.
                         join(
                           self[:app_usage_events].
                           select { Sequel.as(max.function(:id), :id) }.
                           exclude(task_guid: self[:tasks].select(:guid)).
                           group_by(:task_guid).
                           having { count.function.* < 2 },
                         id: :id)

    events_to_backfill.each do |started_event|
      next unless started_event[:state] == 'TASK_STARTED'

      cloned_event_hash = started_event.clone
      cloned_event_hash.delete(:id)
      cloned_event_hash.merge!(
        guid: SecureRandom.uuid,
        state: 'TASK_STOPPED',
        created_at: started_event[:created_at] + 1.second
      )

      self[:app_usage_events].insert(cloned_event_hash)
    end
  end
end
