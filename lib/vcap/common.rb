# Copyright (c) 2009-2011 VMware, Inc.
require 'fileutils'
require 'socket'
require 'uuidtools'

require 'vcap/stats'

# VMware's Cloud Application Platform

module VCAP
  WINDOWS = RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/

  def self.symbolize_keys(hash)
    if hash.is_a? Hash
      new_hash = {}
      hash.each { |k, v| new_hash[k.to_sym] = symbolize_keys(v) }
      new_hash
    else
      hash
    end
  end

  def self.process_running?(pid)
    return false unless pid && (pid > 0)
    output = if WINDOWS
               `tasklist /nh /fo csv /fi "pid eq #{pid}"`
             else
               `ps -o rss= -p #{pid}`
             end
    return true if $CHILD_STATUS == 0 && !output.empty?
    # fail otherwise..
    false
  end

  def self.num_cores
    if RUBY_PLATFORM.match?(/linux/)
      return `cat /proc/cpuinfo | grep processor | wc -l`.to_i
    elsif RUBY_PLATFORM.match?(/darwin/)
      `sysctl -n hw.ncpu`.strip.to_i
    elsif RUBY_PLATFORM.match?(/freebsd|netbsd/)
      `sysctl hw.ncpu`.strip.to_i
    elsif WINDOWS
      (ENV['NUMBER_OF_PROCESSORS'] || 1).to_i
    else
      return 1 # unknown..
    end
  rescue
    # In any case, let's always assume that there is 1 core
    1
  end

  def self.local_ip(route=A_ROOT_SERVER)
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

  class PidFile
    class ProcessRunningError < StandardError
    end

    def initialize(pid_file, create_parents=true)
      @pid_file = pid_file
      @dirty = true
      write(create_parents)
    end

    # Removes the created pidfile
    def unlink
      return unless @dirty

      # Swallowing exception here is fine. Removing the pid files is a courtesy.
      begin
        File.unlink(@pid_file)
        @dirty = false
      rescue
      end
      self
    end

    def unlink_at_exit
      at_exit { unlink }
      self
    end

    def to_s
      @pid_file
    end

    protected

    # Atomically writes the pidfile.
    # NB: This throws exceptions if the pidfile contains the pid of another running process.
    #
    # +create_parents+  If true, all parts of the path up to the file's dirname will be created.
    #
    def write(create_parents=true)
      FileUtils.mkdir_p(File.dirname(@pid_file)) if create_parents

      # Protip from Wilson: binary mode keeps things sane under Windows
      # Closing the fd releases our lock
      File.open(@pid_file, 'a+b', 0644) do |f|
        f.flock(File::LOCK_EX)

        # Check if process is already running
        pid = f.read.strip.to_i
        if pid == Process.pid
          break
        elsif VCAP.process_running?(pid)
          raise ProcessRunningError.new(sprintf('Process already running (pid=%d).', pid))
        end

        # We're good to go, write our pid
        f.truncate(0)
        f.rewind
        f.write(sprintf("%d\n", Process.pid))
        f.flush
      end
    end
  end # class PidFile
end
