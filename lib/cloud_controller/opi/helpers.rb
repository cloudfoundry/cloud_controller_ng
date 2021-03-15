module OPI
  PROMETHEUS_PREFIX = 'prometheus.io'.freeze

  class DockerLifecycle
    def initialize(process)
      @process = process
    end

    def to_hash
      command = if @process.command.presence
                  ['/bin/sh', '-c', @process.command]
                else
                  []
                end
      {
        docker_lifecycle: {
          command: command,
          image: @process.desired_droplet.docker_receipt_image,
          registry_username: @process.desired_droplet.docker_receipt_username,
          registry_password: @process.desired_droplet.docker_receipt_password,
        }
      }
    end
  end

  class BuildpackLifecycle
    def initialize(process)
      @process = process
    end

    def to_hash
      {
        buildpack_lifecycle: {
          start_command: @process.specified_or_detected_command,
          droplet_hash: @process.desired_droplet.droplet_hash,
          droplet_guid: @process.desired_droplet.guid,
        }
      }
    end
  end

  class KpackLifecycle
    CNB_LAUNCHER_PATH = '/cnb/lifecycle/launcher'.freeze

    def initialize(process)
      @process = process
    end

    def to_hash
      command = if @process.started_command.presence
                  [CNB_LAUNCHER_PATH.to_s, @process.started_command.to_s]
                else
                  []
                end
      {
        docker_lifecycle: {
          command: command,
          image: @process.desired_droplet.docker_receipt_image,
        }
      }
    end
  end

  def self.recursive_ostruct(hash)
    OpenStruct.new(hash.map { |key, value|
                     new_val = value.is_a?(Hash) ? recursive_ostruct(value) : value
                     [key, new_val]
                   }.to_h)
  end

  def self.lifecycle_for(process)
    case process.app.droplet.lifecycle_type
    when VCAP::CloudController::Lifecycles::DOCKER
      DockerLifecycle.new(process)
    when VCAP::CloudController::Lifecycles::KPACK
      KpackLifecycle.new(process)
    when VCAP::CloudController::Lifecycles::BUILDPACK
      BuildpackLifecycle.new(process)
    else
      raise("lifecycle type `#{process.app.lifecycle_type}` is invalid")
    end
  end

  def self.filter_annotations(annotations)
    annotations.select { |anno| is_prometheus?(anno)
    }.map { |anno| ["#{anno.key_prefix}/#{anno.key}", anno.value] }.to_h
  end

  def self.is_prometheus?(anno)
    !anno.key_prefix.nil? && anno.key_prefix.start_with?(PROMETHEUS_PREFIX)
  end

  def self.routes(process)
    routing_info = VCAP::CloudController::Diego::Protocol::RoutingInfo.new(process).routing_info
    (routing_info['http_routes'] || []).map do |i|
      {
        hostname: i['hostname'],
        port: i['port']
      }
    end
  end

  def self.environment_variables(process)
    initial_env = ::VCAP::CloudController::EnvironmentVariableGroup.running.environment_json
    opi_env = initial_env.merge(process.environment_json || {}).
              merge('VCAP_APPLICATION' => vcap_application(process), 'MEMORY_LIMIT' => "#{process.memory}m").
              merge(SystemEnvPresenter.new(process.service_bindings).system_env)

    opi_env = opi_env.merge(DATABASE_URL: process.database_uri) if process.database_uri
    opi_env.merge(port_environment_variables(process))
  end

  def self.port_environment_variables(process)
    port = process.open_ports.first
    {
      PORT: port.to_s,
      VCAP_APP_PORT: port.to_s,
      VCAP_APP_HOST: '0.0.0.0'
    }
  end

  def self.vcap_application(process)
    VCAP::VarsBuilder.new(process).to_hash.reject do |k, _v|
      [:users].include? k
    end
  end

  def self.process_guid(process)
    "#{process.guid}-#{process.version}"
  end

  def self.hash_values_to_s(hash)
    Hash[hash.map do |k, v|
      case v
      when Array, Hash
        v = MultiJson.dump(v)
      else
        v = v.to_s
      end

      [k.to_s, v]
    end]
  end
end
