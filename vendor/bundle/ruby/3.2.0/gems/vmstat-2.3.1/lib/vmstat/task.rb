module Vmstat
  # Per task performance metrics snapshot.
  # @attr [Fixnum] virtual_size
  #   The number of virtual pages for the task.
  # @attr [Fixnum] resident_size
  #   The number of resident pages for the task
  # @attr [Fixnum] user_time_ms
  #   The total user run time for terminated threads within the task.
  # @attr [Fixnum] system_time_ms
  #   The total system run time for terminated threads within the task.
  class Task < Struct.new(:virtual_size, :resident_size,
                          :user_time_ms, :system_time_ms)
  end
end
