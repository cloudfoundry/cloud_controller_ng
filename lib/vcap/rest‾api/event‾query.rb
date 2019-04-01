module VCAP::RestAPI
  #
  # Use this class to implement special-cases for querying against
  # the Event Controller

  class EventQuery < Query
    private

    def foreign_key_association(key)
      # Don't admit events have an fkey association with spaces, as events can live
      # after an associated spaces has been deleted.
      nil
    end
  end
end
