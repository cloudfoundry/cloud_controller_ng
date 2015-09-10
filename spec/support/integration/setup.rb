require 'English'

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
      Process.kill('KILL', @nats_pid)
      @nats_pid = nil
    end
  end

  def start_cc(opts={})
    config_file = opts[:config] || 'config/cloud_controller.yml'
    config = YAML.load_file(config_file)

    FileUtils.rm(config['pid_filename']) if File.exist?(config['pid_filename'])

    db_connection_string = "#{TestConfig.config[:db][:database]}_integration_cc"
    if !opts[:preserve_database]
      env = {
        'DB_CONNECTION_STRING' => db_connection_string,
      }.merge(opts[:env] || {})
      run_cmd('bundle exec rake db:recreate db:migrate', wait: true, env: env)
    end

    @cc_pids ||= []
    @cc_pids << run_cmd("bin/cloud_controller -s -c #{config_file}", opts.merge(env: { 'DB_CONNECTION_STRING' => db_connection_string }.merge(opts[:env] || {})))

    info_endpoint = "http://localhost:#{config['external_port']}/info"

    Integer(CC_START_TIMEOUT / SLEEP_INTERVAL).times do
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
    Timeout.timeout(10) do
      loop do
        sleep 0.2
        break if nats_up?(port)
      end
    end
  end

  def nats_up?(port)
    NATS.start(uri: "nats://127.0.0.1:#{port}") do
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
    project_path = File.join(File.dirname(__FILE__), '../../..')
    spawn_opts = {
      chdir: project_path,
      out: opts[:debug] ? :out : '/dev/null',
      err: opts[:debug] ? :out : '/dev/null',
    }

    pid = Process.spawn(opts[:env], cmd, spawn_opts)

    if opts[:wait]
      Process.wait(pid)
      raise "`#{cmd}` exited with #{$CHILD_STATUS}" unless $CHILD_STATUS.success?
    end

    pid
  end

  def graceful_kill(name, pid)
    Process.kill('TERM', pid)
    Timeout.timeout(1) do
      Process.wait(pid)
    end
  rescue Timeout::Error
    Process.detach(pid)
    Process.kill('KILL', pid)
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
