class EligibleDeaAdvertisementFilter
  def initialize(dea_advertisements, app_id)
    @all_advertisements = dea_advertisements
    @dea_advertisements = dea_advertisements.dup
    @app_id = app_id
  end

  def only_with_disk(minimum_disk)
    @dea_advertisements.select! { |ad| ad.has_sufficient_disk?(minimum_disk) }
    self
  end

  def only_meets_needs(mem, stack)
    @dea_advertisements.select! { |ad| ad.meets_needs?(mem, stack) }
    self
  end

  def only_fewest_instances_of_app()
    fewest_instances_of_app = @dea_advertisements.map { |ad| ad.num_instances_of(@app_id) }.min
    @dea_advertisements.select! { |ad| ad.num_instances_of(@app_id) == fewest_instances_of_app }
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

  def only_in_zone_with_fewest_instances()
    min_in_zone = @dea_advertisements.map { |ad| number_in_zone(ad.zone) }.min
    @dea_advertisements.select! { |ad| number_in_zone(ad.zone) == min_in_zone }
    self
  end

  private

  def number_in_zone(zone)
    @_numinzone ||= {}
    @_numinzone[zone] ||= @all_advertisements.inject(0) do |count, ad|
      count += ad.num_instances_of(@app_id) if ad.zone == zone
      count
    end
  end
end