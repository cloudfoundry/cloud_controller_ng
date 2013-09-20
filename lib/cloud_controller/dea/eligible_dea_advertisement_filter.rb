class EligibleDeaAdvertisementFilter
  def initialize(dea_advertisements)
    @dea_advertisements = dea_advertisements.dup
  end

  def only_meets_needs(mem, stack)
    @dea_advertisements.select! { |ad| ad.meets_needs?(mem, stack) }
    self
  end

  def only_fewest_instances_of_app(app_id)
    fewest_instances_of_app = @dea_advertisements.map { |ad| ad.num_instances_of(app_id) }.min
    @dea_advertisements.select! { |ad| ad.num_instances_of(app_id) == fewest_instances_of_app }
    self
  end

  def upper_half_by_memory
    unless @dea_advertisements.empty?
      @dea_advertisements.sort_by! { |ad| ad.available_memory }
      min_eligible_memory = @dea_advertisements[@dea_advertisements.size/2].available_memory
      @dea_advertisements.select! { |ad| ad.available_memory >= min_eligible_memory }
    end

    self
  end

  def sample
    @dea_advertisements.sample
  end
end