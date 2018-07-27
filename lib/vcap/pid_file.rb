require 'fileutils'
require 'vcap/host_system'

module VCAP
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
        elsif HostSystem.new.process_running?(pid)
          raise ProcessRunningError.new(sprintf('Process already running (pid=%<pid>d).', pid: pid))
        end

        # We're good to go, write our pid
        f.truncate(0)
        f.rewind
        f.write(sprintf("%<pid>d\n", pid: Process.pid))
        f.flush
      end
    end
  end
end
