module VCAP::CloudController
  class ResourceMatch
    attr_reader :descriptors

    FILE_SIZE_GROUPS = {
      '1KB or less': 0...1.kilobyte,
      '1KB to 100KB': 1.kilobyte...100.kilobytes,
      '100KB to 1MB': 100.kilobytes...1.megabyte,
      '1MB to 100MB': 1.megabyte...100.megabytes,
      '100MB to 1GB': 100.megabytes...1.gigabyte,
      '1GB or more': 1.gigabyte..Float::INFINITY
    }.freeze

    def initialize(descriptors)
      @descriptors = descriptors
    end

    def match_resources
      count_by_size = resource_count_by_filesize
      before_match_log(count_by_size)

      time_by_bucket = FILE_SIZE_GROUPS.keys.index_with do |_key|
        0
      end

      known_resources = []
      resources_by_filesize.each do |name, resources|
        resources.each do |resource|
          start_time = Time.now
          exists = resource_pool.resource_known?(resource)
          duration = Time.now - start_time
          known_resources << resource if exists
          time_by_bucket[name] += duration
          logger.debug('resource_match.exists.call', {
                         sha1: resource['sha1'],
                         size: resource['size'],
                         exists: exists,
                         duration_seconds: duration.round(4)
                       })
        end
      end
      after_match_log(time_by_bucket, known_resources.count, count_by_size)
      known_resources
    end

    def resource_count_by_filesize
      counted = resources_by_filesize.transform_values(&:count)
      # start with FILE_SIZE_GROUPS to preserve hash key ordering
      FILE_SIZE_GROUPS.keys.index_with do |key|
        counted[key] || 0
      end
    end

    private

    def resources_by_filesize
      allowed_resources.group_by do |descriptor|
        FILE_SIZE_GROUPS.detect { |_key, range| range.include?(descriptor['size']) }.first
      end
    end

    def before_match_log(count_by_size)
      logger.info('starting resource matching', {
                    total_resources_to_match: allowed_resources.count,
                    resource_count_by_size: count_by_size
                  })
    end

    def after_match_log(time_by_bucket, cache_hits, count_by_size)
      total_time = time_by_bucket.sum { |_bucket, count| count }
      total = allowed_resources.count
      cache_misses = total - cache_hits
      logger.info('done matching resources', {
                    total_resources_to_match: total,
                    cache_hits: cache_hits,
                    cache_misses: cache_misses,
                    cache_hit_rate: total > 0 ? (cache_hits.to_f / total).round(4) : 0,
                    avg_resource_match_time: total > 0 ? "#{(total_time / total).round(4)} seconds" : '0 seconds',
                    total_resource_match_time: "#{total_time.to_f.round(2)} seconds",
                    resource_count_by_size: count_by_size,
                    resource_match_time_by_size: time_by_bucket.transform_values { |count| "#{count.to_f.round(2)} seconds" }
                  })
    end

    def allowed_resources
      @allowed_resources ||= descriptors.select do |descriptor|
        resource_pool.size_allowed?(descriptor['size']) && resource_pool.mode_allowed?(descriptor['mode'])
      end
    end

    def logger
      @logger ||= Steno.logger('cc.resource_pool')
    end

    def resource_pool
      @resource_pool ||= VCAP::CloudController::ResourcePool.instance
    end
  end
end
