module VCAP::CloudController
  class ProcessStatsPresenter
    def present_stats_hash(type, process_stats)
      process_stats.each.map do |index, instance_stats|
        instance_stats_hash(type, index, instance_stats)
      end.sort_by { |s| s[:index] }
    end

    private

    def instance_stats_hash(type, index, stats)
      case stats['state']
      when 'DOWN'
        down_instance_stats_hash(type, index, stats)
      else
        found_instance_stats_hash(type, index, stats)
      end
    end

    def found_instance_stats_hash(type, index, stats)
      {
        type:       type,
        index:      index,
        state:      stats['state'],
        usage:      {
          time: stats['stats']['usage']['time'],
          cpu:  stats['stats']['usage']['cpu'],
          mem:  stats['stats']['usage']['mem'],
          disk: stats['stats']['usage']['disk'],
        },
        host:       stats['stats']['host'],
        port:       stats['stats']['port'],
        uptime:     stats['stats']['uptime'],
        mem_quota:  stats['stats']['mem_quota'],
        disk_quota: stats['stats']['disk_quota'],
        fds_quota:  stats['stats']['fds_quota']
      }
    end

    def down_instance_stats_hash(type, index, stats)
      {
        type: type,
        index: index,
        state: stats['state'],
        uptime: stats['uptime']
      }
    end
  end
end
