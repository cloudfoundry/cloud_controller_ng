module VCAP::CloudController
  class ResourceMatch
    attr_reader :descriptors, :minimum_size, :maximum_size, :resource_batch_id

    FILE_SIZE_GROUPS = {
      '1KB or less':    0...1.kilobyte,
      '1KB to 100KB':   1.kilobyte...100.kilobytes,
      '100KB to 1MB':   100.kilobytes...1.megabyte,
      '1MB to 100MB':   1.megabyte...100.megabytes,
      '100MB to 1GB':   100.megabytes...1.gigabyte,
      '1GB or more':    1.gigabyte..Float::INFINITY
    }.freeze

    def initialize(descriptors)
      @descriptors = descriptors
    end

    def match_resources
      before_match_log

      time_by_bucket = FILE_SIZE_GROUPS.keys.each_with_object({}) do |key, hash|
        hash[key] = 0
      end

      known_resources = []
      resources_by_filesize.each do |name, resources|
        resources.each do |resource|
          start_time = Time.now
          known_resources << resource if resource_pool.resource_known?(resource)
          time_by_bucket[name] += Time.now - start_time
        end
      end
      after_match_log(time_by_bucket)
      known_resources
    end

    def resource_count_by_filesize
      counted = resources_by_filesize.transform_values(&:count)
      # start with FILE_SIZE_GROUPS to preserve hash key ordering
      FILE_SIZE_GROUPS.keys.each_with_object({}) do |key, hash|
        hash[key] = counted[key] || 0
      end
    end

    private

    def resources_by_filesize
      allowed_resources.group_by do |descriptor|
        FILE_SIZE_GROUPS.detect { |_key, range| range.include?(descriptor['size']) }.first
      end
    end

    def before_match_log
      logger.info('starting resource matching', {
        total_resources_to_match: allowed_resources.count,
        resource_count_by_size: resource_count_by_filesize
      })
    end

    def after_match_log(time_by_bucket)
      total_time = time_by_bucket.sum { |_bucket, count| count }
      logger.info('done matching resources', {
        total_resources_to_match: allowed_resources.count,
        total_resource_match_time: "#{total_time.to_f.round(2)} seconds",
        resource_count_by_size: resource_count_by_filesize,
        resource_match_time_by_size: time_by_bucket.transform_values { |count| "#{count.to_f.round(2)} seconds" }
      })
    end

    def allowed_resources
      @allowed_resources ||= descriptors.select { |descriptor| resource_pool.size_allowed?(descriptor['size']) }
    end

    def logger
      @logger ||= Steno.logger('cc.resource_pool')
    end

    def resource_pool
      @resource_pool ||= VCAP::CloudController::ResourcePool.instance
    end
  end
end
