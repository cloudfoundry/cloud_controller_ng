module IntegrationSetup
  def start_nats(opts={})
    port = opts[:port] || 4222
    @nats_pid = run_cmd("nats-server -V -D -p #{port}", opts)
    wait_for_nats_to_start(port)
  end

  def stop_nats
    graceful_kill(:nats, @nats_pid)
  end

  def kill_nats
    Process.kill("KILL", @nats_pid)
    sleep 2
  end

  def start_cc(opts={}, wait_cycles = 20)
    config_file = opts[:config] || "config/cloud_controller.yml"
    config = YAML.load_file(config_file)
    run_cmd("bundle exec rake db:migrate", :wait => true)
    @cc_pids ||= []
    @cc_pids << run_cmd("bin/cloud_controller -m -c #{config_file}", opts)

    info_endpoint = "http://localhost:#{config["port"]}/info"
    wait_cycles.times do
      sleep 1
      result = Net::HTTP.get_response(URI.parse(info_endpoint)) rescue nil
      return if result && result.code.to_i == 200
    end

    raise "Cloud controller did not start up after #{wait_cycles}s"
  end

  def stop_cc
    return unless @cc_pids
    @cc_pids.each { |pid| graceful_kill(:cc, pid) }
  end

  def wait_for_nats_to_start(port)
    Timeout::timeout(10) do
      loop do
        sleep 0.2
        break if nats_up?(port)
      end
    end
  end

  def nats_up?(port)
    NATS.start(:uri => "nats://127.0.0.1:#{port}") do
      NATS.stop
      return true
    end
  rescue NATS::ConnectError
    nil
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
  rspec_config.include(IntegrationSetup, :type => :integration)

  rspec_config.before(:all, :type => :integration) do
    WebMock.allow_net_connect!
  end

  rspec_config.after(:all, :type => :integration) do
    WebMock.disable_net_connect!
  end
end
