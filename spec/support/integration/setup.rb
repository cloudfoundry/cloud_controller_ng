module IntegrationSetup
  CC_START_TIMEOUT = 20
  SLEEP_INTERVAL = 0.5
  def start_nats(opts={})
    port = opts[:port] || 4222
    @nats_pid = run_cmd("nats-server -V -D -p #{port}", opts)
    wait_for_nats_to_start(port)
  end

  def stop_nats
    if @nats_pid
      graceful_kill(:nats, @nats_pid)
      @nats_pid = nil
    end
  end

  def kill_nats
    if @nats_pid
      Process.kill("KILL", @nats_pid)
      @nats_pid = nil
    end
  end

  def start_cc(opts={})
    config_file = opts[:config] || "config/cloud_controller.yml"
    config = YAML.load_file(config_file)

    FileUtils.rm(config['pid_filename']) if File.exists?(config['pid_filename'])

    database_file = config["db"]["database"].gsub('sqlite://', '')
    if !opts[:preserve_database] && File.file?(database_file)
      run_cmd("rm -f #{database_file}", wait: true)
    end

    run_cmd("bundle exec rake db:migrate", wait: true)
    @cc_pids ||= []
    @cc_pids << run_cmd("bin/cloud_controller -s -c #{config_file}", opts)

    info_endpoint = "http://localhost:#{config["external_port"]}/info"

    Integer(CC_START_TIMEOUT/SLEEP_INTERVAL).times do
      sleep SLEEP_INTERVAL
      result = Net::HTTP.get_response(URI.parse(info_endpoint)) rescue nil
      return if result && result.code.to_i == 200
    end

    raise "Cloud controller did not start up after #{CC_START_TIMEOUT}s"
  end

  def stop_cc
    @cc_pids.dup.each { |pid| graceful_kill(:cc, @cc_pids.delete(pid)) }
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

  def start_fake_service_broker
    kill_existing_fake_broker
    fake_service_broker_path = File.expand_path(File.join(File.dirname(__FILE__), 'fake_service_broker.rb'))
    @fake_service_broker_pid = run_cmd("ruby #{fake_service_broker_path}")
  end

  def kill_existing_fake_broker
    if existing_broker_process = `ps -o pid,command`.split("\n").find { |s| s[/\d+.*fake_service_broker/] }
      Process.kill('KILL', existing_broker_process[/\d+/].to_i)
    end
  end

  def fake_service_broker_is_running?
    @fake_service_broker_pid && process_alive?(@fake_service_broker_pid)
  end

  def stop_fake_service_broker
    Process.kill("KILL", @fake_service_broker_pid) if fake_service_broker_is_running?
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
    Timeout::timeout(1) do
      Process.wait(pid)
    end
  rescue Timeout::Error
    Process.detach(pid)
    Process.kill("KILL", pid)
  rescue Errno::ESRCH
    true
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
    $spec_env.reset_database_with_seeds
  end
end
