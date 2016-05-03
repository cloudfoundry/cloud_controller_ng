module VCAP::CloudController
  class ProcessStatsPresenter
    def initialize(type, process_stats)
      @type = type
      @process_stats = process_stats
    end

    def present_stats_hash
      @process_stats.map do |index, instance_stats|
        instance_stats_hash(index, instance_stats)
      end.sort_by { |s| s[:index] }
    end

    def to_json
      MultiJson.dump({ resources: present_stats_hash }, pretty: true)
    end

    private

    def instance_stats_hash(index, stats)
      case stats[:state]
      when 'DOWN'
        down_instance_stats_hash(index, stats)
      else
        found_instance_stats_hash(index, stats)
      end
    end

    def found_instance_stats_hash(index, stats)
      {
        type:       @type,
        index:      index,
        state:      stats[:state],
        usage:      {
          time: stats[:stats][:usage][:time],
          cpu:  stats[:stats][:usage][:cpu],
          mem:  stats[:stats][:usage][:mem],
          disk: stats[:stats][:usage][:disk],
        },
        host:       stats[:stats][:host],
        uptime:     stats[:stats][:uptime],
        mem_quota:  stats[:stats][:mem_quota],
        disk_quota: stats[:stats][:disk_quota],
        fds_quota:  stats[:stats][:fds_quota]
      }.tap { |presented_stats| add_port_info(presented_stats, stats) }
    end

    def down_instance_stats_hash(index, stats)
      {
        type: @type,
        index: index,
        state: stats[:state],
        uptime: stats[:uptime]
      }
    end

    def add_port_info(presented_stats, stats)
      if stats[:stats][:net_info]
        presented_stats[:instance_ports] = net_info_to_instance_ports(stats[:stats][:net_info])
      else
        presented_stats[:port] = stats[:stats][:port]
      end
    end

    def net_info_to_instance_ports(net_info)
      net_info[:ports].map do |ports|
        {
          external: ports[:host_port],
          internal: ports[:container_port],
        }
      end
    end
  end
end
