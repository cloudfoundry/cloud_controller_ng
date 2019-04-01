class SpaceRoutes
  def initialize(space)
    @space = space
  end

  def count
    @space.routes.count
  end
end
