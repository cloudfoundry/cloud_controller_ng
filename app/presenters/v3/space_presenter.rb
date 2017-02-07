module VCAP::CloudController::Presenters::V3
  class SpacePresenter < BasePresenter
    def to_hash
      {
        guid: space.guid,
        created_at: space.created_at,
        updated_at: space.updated_at,
        name: space.name,
        links: {},
      }
    end

    private

    def space
      @resource
    end
  end
end
