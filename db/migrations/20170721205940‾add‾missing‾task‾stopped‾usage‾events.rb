require 'securerandom'

Sequel.migration do
  change do
    # This migration was emptied because it performed an n^2 operation against
    # app_usage_events, a large table (millions of rows) using columns
    # that are not indexed. This can lead to this migration taking dozens of days.
    #
    # A future migration with better performance will be added in the future
  end
end
