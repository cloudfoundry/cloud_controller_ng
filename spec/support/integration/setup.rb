require 'English'

module IntegrationSetup
  CC_START_TIMEOUT = 20
  SLEEP_INTERVAL = 0.5
  def start_nats(opts={})
    port = opts.delete(:port) || 4222
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
    @cc_pids ||= []

    config_file = opts[:config] || 'config/cloud_controller.yml'
    config = YAML.load_file(config_file)

    FileUtils.rm(config['pid_filename']) if File.exist?(config['pid_filename'])

    db_connection_string = "#{TestConfig.config[:db][:database]}_integration_cc"
    if !opts[:preserve_database]
      db = /postgres/ =~ db_connection_string ? 'postgres' : 'mysql'
      env = {
        'DB_CONNECTION_STRING' => db_connection_string,
        'DB' => db
      }.merge(opts[:env] || {})
      run_cmd('bundle exec rake db:recreate db:migrate', wait: true, env: env)
      run_cmd('bundle exec rake db:seed', wait: true, env: env, continue_on_failure: true)
    end

    @cc_pids << run_cmd("bin/cloud_controller -c #{config_file}", opts.merge(env: { 'DB_CONNECTION_STRING' => db_connection_string }.merge(opts[:env] || {})))

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

    spawn_opts = { chdir: project_path }

    if opts[:wait]
      stdout, stderr, child_status = Open3.capture3(opts[:env], cmd, spawn_opts)
      pid = child_status.pid

      unless child_status.success? || opts[:continue_on_failure]
        raise "`#{cmd}` exited with #{child_status} #{coredump_text(child_status)}\n#{failure_output(stdout, stderr)}"
      end
    else
      spawn_opts[:out] = opts[:debug] ? :out : '/dev/null'
      spawn_opts[:err] = opts[:debug] ? :out : '/dev/null'

      pid = Process.spawn(opts[:env], cmd, spawn_opts)
    end

    pid
  end

  def graceful_kill(_name, pid)
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

  private

  def coredump_text(status)
    status.coredump? ? '(core dumped)' : '(without core dump)'
  end

  def failure_output(stdout, stderr)
    "================ STDOUT\n" \
    "#{stdout}\n" \
    "================ STDERR\n" \
    "#{stderr}"
  end
end
