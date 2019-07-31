require 'socket'

module VCAP
  class HostSystem
    def process_running?(pid)
      return false unless pid && (pid > 0)

      output = `ps -o rss= -p #{pid}`
      return true if $CHILD_STATUS == 0 && !output.empty?

      # fail otherwise..
      false
    end

    def num_cores
      if RUBY_PLATFORM.match?(/linux/)
        `cat /proc/cpuinfo | grep processor | wc -l`.to_i
      elsif RUBY_PLATFORM.match?(/darwin/)
        `sysctl -n hw.ncpu`.strip.to_i
      elsif RUBY_PLATFORM.match?(/freebsd|netbsd/)
        `sysctl hw.ncpu`.strip.to_i
      else
        1 # unknown..
      end
    rescue
      # In any case, let's always assume that there is 1 core
      1
    end

    def local_ip(route=A_ROOT_SERVER)
      route ||= A_ROOT_SERVER
      orig = Socket.do_not_reverse_lookup
      Socket.do_not_reverse_lookup = true
      UDPSocket.open do |s|
        s.connect(route, 1)
        s.addr.last
      end
    ensure
      Socket.do_not_reverse_lookup = orig
    end
  end
end
