module IntegrationSetup
  def start_nats(opts={})
    before(:all) { @nats_pid = run_cmd("nats-server -V -D", opts) }
    before(:all) { check_process_alive!(:nats, @nats_pid, :sleep => 0.5) }
    after(:all) { graceful_kill(:nats, @nats_pid) }
  end

  def start_cc(opts={})
    before(:all) { @cc_pid = run_cmd("bundle exec rake db:migrate && bin/cloud_controller config/cloud_controller.yml", opts) }
    before(:all) { check_process_alive!(:cc, @cc_pid, :sleep => 10) }
    after(:all) { graceful_kill(:dea, @cc_pid) }
  end
end

module IntegrationHelpers
  def run_cmd(cmd, opts={})
    project_path = File.join(File.dirname(__FILE__), "../..")
    spawn_opts = {
      :chdir => project_path,
      :out => opts[:debug] ? :out : "/dev/null",
      :err => opts[:debug] ? :out : "/dev/null",
    }

    Process.spawn(cmd, spawn_opts).tap do |pid|
      if opts[:wait]
        Process.wait(pid)
        raise "`#{cmd}` exited with #{$?}" unless $?.success?
      end
    end
  end

  def check_process_alive!(name, pid, options={})
    sleep(options[:sleep]) if options[:sleep]
    raise "Process #{name} with pid #{pid} is not alive." \
      unless process_alive?(pid)
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
  rspec_config.include(IntegrationHelpers, :type => :integration)
  rspec_config.extend(IntegrationSetup, :type => :integration)

  rspec_config.before(:each, :type => :integration) do
    WebMock.allow_net_connect!
  end

  rspec_config.after(:each, :type => :integration) do
    WebMock.disable_net_connect!
  end
end
