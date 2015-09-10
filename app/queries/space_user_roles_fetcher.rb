module VCAP::CloudController
  class SpaceUserRolesFetcher
    def fetch(space)
      space.developers_dataset.
      union(space.managers_dataset, from_self: false).
      union(space.auditors_dataset, from_self: false).
      eager(:spaces, :managed_spaces, :audited_spaces)
    end
  end
end
