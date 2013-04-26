module IntegrationSetup
  def start_nats(opts={})
    before(:all) do
      @nats_pid = run_cmd("nats-server -V -D", opts)
      sleep 0.5
      unless process_alive?(@nats_pid)
        raise "nats-server is not running"
      end
    end

    after(:all) { graceful_kill(:nats, @nats_pid) }
  end

  # TODO(David & Kowshik): Rewrite this.
  def start_cc(opts={})
    before(:all) do
      @cc_pid = run_cmd("bundle exec rake db:migrate && bin/cloud_controller config/cloud_controller.yml", opts)
      wait_cycles = 0
      while wait_cycles < 20
        sleep 1
        begin
          result = Net::HTTP.get_response(URI.parse("http://localhost:8181/info"))
        rescue Errno::ECONNREFUSED
          # ignore
        end
        break if result && result.code.to_i == 200
        wait_cycles += 1
      end

      raise "Cloud controller did not start up after #{wait_cycles}s" if wait_cycles == 20
    end
    after(:all) { graceful_kill(:cc, @cc_pid) }
  end
end

module IntegrationSetupHelpers
  def run_cmd(cmd, opts={})
    opts[:env] ||= {}
    project_path = File.join(File.dirname(__FILE__), "../../..")
    spawn_opts = {
      :chdir => project_path,
      :out => opts[:debug] ? :out : "/dev/null",
      :err => opts[:debug] ? :out : "/dev/null",
    }

    pid = Process.spawn(opts[:env], cmd, spawn_opts)

    if opts[:wait]
      Process.wait(pid)
      raise "`#{cmd}` exited with #{$?}" unless $?.success?
    end

    pid
  end

  def graceful_kill(name, pid)
    Process.kill("TERM", pid)
    Timeout.timeout(1) do
      while process_alive?(pid) do
      end
    end
  rescue Timeout::Error
    Process.kill("KILL", pid)
  end

  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end
end

RSpec.configure do |rspec_config|
  rspec_config.include(IntegrationSetupHelpers, :type => :integration)
  rspec_config.extend(IntegrationSetup, :type => :integration)

  rspec_config.before(:all, :type => :integration) do
    WebMock.allow_net_connect!
  end

  rspec_config.after(:all, :type => :integration) do
    WebMock.disable_net_connect!
  end
end
