module VCAP::CloudController
  class SpaceReservedRoutePorts
    def initialize(space)
      @space = space
    end

    delegate :count, to: :dataset

    private

    def dataset
      Route.dataset.select_all(Route.table_name).
        join(Domain.table_name, id: :domain_id).
        where(space_id: @space.id).
        exclude(domains__router_group_guid: nil).
        exclude(routes__port: nil)
    end
  end
end
