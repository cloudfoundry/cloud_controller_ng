class SpaceRoutes
  def initialize(space)
    @space = space
  end

  def count
    @space.routes_dataset.count
  end
end
