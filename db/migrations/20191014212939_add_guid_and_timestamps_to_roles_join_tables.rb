Sequel.migration do
  change do
    # This is a no-op. We split this migration into 7 migrations, one for each table, to prevent deadlocks.
    # See https://www.pivotaltracker.com/story/show/170321550 for more info,
    # and https://github.com/cloudfoundry/cloud_controller_ng/issues/1133 for a similar issue + solution.
  end
end
