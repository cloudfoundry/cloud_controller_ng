class EligibleDeaAdvertisementFilter
  def initialize(advertisements, criteria)
    @filtered_advertisements = advertisements.dup
    @zones = VCAP::CloudController::Config.zones
    @criteria = criteria
    @app_id = criteria[:app_id]

    @instance_counts_by_zones = Hash.new(0)
    advertisements.each { |ad| @instance_counts_by_zones[ad.zone] += ad.num_instances_of(@app_id) }
  end

  def only_with_disk
    @filtered_advertisements.select! { |ad| ad.has_sufficient_disk?(@criteria[:disk] || 0) }
    self
  end

  def only_meets_needs
    @filtered_advertisements.select! { |ad| ad.meets_needs?(@criteria[:mem], @criteria[:stack]) }
    self
  end

  def only_fewest_instances_of_app
    fewest_instances_of_app = @filtered_advertisements.map { |ad| ad.num_instances_of(@app_id) }.min
    @filtered_advertisements.select! { |ad| ad.num_instances_of(@app_id) == fewest_instances_of_app }
    self
  end

  def upper_half_by_memory
    unless @filtered_advertisements.empty?
      @filtered_advertisements.sort_by! { |ad| ad.available_memory }
      min_eligible_memory = @filtered_advertisements[@filtered_advertisements.size/2].available_memory
      @filtered_advertisements.select! { |ad| ad.available_memory >= min_eligible_memory }
    end

    self
  end

  def sample
    @filtered_advertisements.sample
  end

  def only_in_zone_with_fewest_instances
    minimum_instance_count = @filtered_advertisements.map { |ad| @instance_counts_by_zones[ad.zone] }.min
    @filtered_advertisements.select! { |ad| @instance_counts_by_zones[ad.zone] == minimum_instance_count }
    self
  end

  def only_fewest_instances_of_all
    unless @filtered_advertisements.empty?
      dummy_ad = Advertisement.new("app_id_to_count" => {"dummy" => Float::INFINITY})
      @filtered_advertisements = @filtered_advertisements.inject([dummy_ad]) do |min_instance_ads, ad|
        if ad.num_instances_of_all < min_instance_ads.first.num_instances_of_all
          min_instance_ads = [ad]
        elsif ad.num_instances_of_all == min_instance_ads.first.num_instances_of_all
          min_instance_ads << ad
        end
        min_instance_ads
      end
    end
    self
  end

  def upper_by_memory
    unless @filtered_advertisements.empty?
      dummy_ad = Advertisement.new("available_memory" => -1)
      @filtered_advertisements = @filtered_advertisements.inject([dummy_ad]) do |max_memory_ads, ad|
        if ad.available_memory > max_memory_ads.first.available_memory
          max_memory_ads = [ad]
        elsif ad.available_memory == max_memory_ads.first.available_memory
          max_memory_ads << ad
        end
        max_memory_ads
      end
    end
    self
  end

  def only_valid_zone
    valid_zones = []
    @zones.each { |zone|
      valid_zones << zone["name"]
    }
    @filtered_advertisements.select! do |ad|
      if valid_zones.include?(ad.zone)
        true
      else
        logger.info "Invalid zone_name: #{ad.zone}", dea_id: ad.id
        false
      end
    end
    self
  end

  def only_specific_zone
    zone = @criteria[:zone].blank? && find_zone || @criteria[:zone]
    @filtered_advertisements.select! { |ad| ad.zone == zone }
    self
  end

  def logger
   @logger ||= Steno.logger("cc.dea.eligible_dea_advertisement_filter")
  end

  private

  def find_main_zone
    main_zone = nil
    if @filtered_advertisements
      @zones.sort_by! { |zone|
        - zone["priority"]
      }.each { |zone|
        if has_capacity?(zone["name"])
          main_zone = zone["name"]
          break
        end
      }
    end
    main_zone
  end

  def find_zone
    if @criteria[:index] == 0
      find_main_zone
    else
      zone = nil
      num_instances_and_deas_each_zone.sort { |a, b|
        (a[1][:num_instances] <=> b[1][:num_instances]).nonzero? ||
        (b[1][:num_dea] <=> a[1][:num_dea])
      }.each { |num_instances_and_deas_in_zone|
        if has_capacity?(num_instances_and_deas_in_zone[0])
          return num_instances_and_deas_in_zone[0]
        end
      }
      zone
    end
  end

  def has_capacity?(zone)
    meets_needs_with_zone?(zone) && meets_disk_with_zone?(zone)
  end

  def meets_disk_with_zone?(zone)
    @filtered_advertisements.select { |ad|
      zone == ad.zone && ad.has_sufficient_disk?(@criteria[:disk] || 0)
    }.size > 0 ? true : false
  end

  def meets_needs_with_zone?(zone)
    @filtered_advertisements.select { |ad|
      zone == ad.zone && ad.meets_needs?(@criteria[:mem], @criteria[:stack])
    }.size > 0 ? true : false
  end

  def num_instances_and_deas_each_zone
    zone_and_num_instances_deas = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    @filtered_advertisements.each { |ad|
      zone_and_num_instances_deas[ad.zone][:num_instances] += ad.num_instances_of(@app_id)
      zone_and_num_instances_deas[ad.zone][:num_dea] += 1
    }
    zone_and_num_instances_deas
  end
end
