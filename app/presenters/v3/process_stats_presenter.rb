module VCAP::CloudController
  class ProcessStatsPresenter
    def present_stats_hash(type, process_stats)
      stats = []
      process_stats.each do |index, instance_stats|
        stats << instance_stats_hash(type, index, instance_stats)
      end
      stats.sort_by { |s| s[:index] }
    end

    private

    def instance_stats_hash(type, index, stats)
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
  end
end
