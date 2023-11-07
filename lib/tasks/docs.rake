namespace :docs do
  def print_events(events, title=nil)
    puts("\n##### #{title.capitalize}\n") unless title.nil?
    group = ''
    events.sort.each do |event|
      event_group = event.split('.')[1]
      if group != event_group && title.nil?
        group = event_group
        puts("\n##### #{group.capitalize} lifecycle")
      end
      puts("- `#{event}`")
    end
  end

  desc 'Generate list of all audit events'
  task audit_events_list: :environment do
    print_events(VCAP::CloudController::Repositories::EventTypes::AUDIT_EVENTS)
    print_events(VCAP::CloudController::Repositories::EventTypes::SPECIAL_EVENTS, 'Special events')
  end
end
