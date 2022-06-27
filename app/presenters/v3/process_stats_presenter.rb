module VCAP::CloudController
  module Presenters
    module V3
      class ProcessStatsPresenter
        def initialize(type, process_stats)
          @type          = type
          @process_stats = process_stats
        end

        def to_hash
          {
            resources: present_stats_hash,
          }
        end

        def present_stats_hash
          @process_stats.map do |index, instance_stats|
            instance_stats_hash(index, instance_stats)
          end.sort_by { |s| s[:index] }
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
            host:       stats[:stats][:host],
            uptime:     stats[:stats][:uptime],
            mem_quota:  stats[:stats][:mem_quota],
            disk_quota: stats[:stats][:disk_quota],
            log_rate_limit:  stats[:stats][:log_rate_limit],
            fds_quota:  stats[:stats][:fds_quota],
            isolation_segment: stats[:isolation_segment],
            details: stats[:details]
          }.tap do |presented_stats|
            add_port_info(presented_stats, stats)
            add_usage_info(presented_stats, stats)
          end
        end

        def down_instance_stats_hash(index, stats)
          {
            type:   @type,
            index:  index,
            state:  stats[:state],
            uptime: stats[:uptime],
            isolation_segment: stats[:isolation_segment],
            details: stats[:details]
          }
        end

        def add_port_info(presented_stats, stats)
          if stats[:stats][:net_info]
            presented_stats[:instance_ports] = net_info_to_instance_ports(stats[:stats][:net_info][:ports])
          else
            presented_stats[:port] = stats[:stats][:port]
          end
        end

        def add_usage_info(presented_stats, stats)
          presented_stats[:usage] = if stats[:stats][:usage].present?
                                      {
                                        time: stats[:stats][:usage][:time],
                                        cpu:  stats[:stats][:usage][:cpu],
                                        mem:  stats[:stats][:usage][:mem],
                                        disk: stats[:stats][:usage][:disk],
                                        log_rate: stats[:stats][:usage][:log_rate],
                                      }
                                    else
                                      {}
                                    end
        end

        def net_info_to_instance_ports(net_info_ports)
          return [] if net_info_ports.nil?

          net_info_ports.map do |ports|
            external_tls_proxy_port_raw = HashUtils.dig(ports, :host_tls_proxy_port)
            internal_tls_proxy_port_raw = HashUtils.dig(ports, :container_tls_proxy_port)

            {
              external: ports[:host_port],
              internal: ports[:container_port],
              external_tls_proxy_port: external_tls_proxy_port_raw.to_i == 0 ? nil : external_tls_proxy_port_raw,
              internal_tls_proxy_port: internal_tls_proxy_port_raw.to_i == 0 ? nil : internal_tls_proxy_port_raw
            }
          end
        end
      end
    end
  end
end
