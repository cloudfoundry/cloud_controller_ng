class MaxRoutesPolicy
  def initialize(quota_defintion, route_counter)
    @quota_definition = quota_defintion
    @route_counter = route_counter
  end

  def allow_more_routes?(number_of_new_routes)
    return true if @quota_definition.total_routes == -1

    existing_total_routes = @route_counter.count
    @quota_definition.total_routes >= (existing_total_routes + number_of_new_routes)
  end
end
