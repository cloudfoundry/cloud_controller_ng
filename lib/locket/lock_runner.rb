require 'steno'
require 'locket/locket_services_pb'

module Locket
  class LockRunner
    class Error < StandardError
    end

    def initialize(key:, owner:, host:, port:, client_ca_path:, client_cert_path:, client_key_path:)
      client_ca = File.read(client_ca_path)
      client_key = File.read(client_key_path)
      client_cert = File.read(client_cert_path)

      @service = Models::Locket::Stub.new(
        "#{host}:#{port}",
        GRPC::Core::ChannelCredentials.new(client_ca, client_key, client_cert)
      )
      @lock_acquired = false

      @key = key
      @owner = owner
    end

    def start
      raise Error.new('Cannot start more than once') if @thread

      @thread = Thread.new do
        failed = false
        loop do
          begin
            service.lock(build_lock_request)
            logger.info("Acquired lock '#{key}' for owner '#{owner}'") unless @lock_acquired
            @lock_acquired = true
            failed = false
          rescue GRPC::BadStatus => e
            logger.info("Failed to acquire lock '#{key}' for owner '#{owner}': #{e.message}") unless failed
            failed = true
            @lock_acquired = false
          end

          sleep 1
        end
      end
    end

    def stop
      @thread.kill if @thread
    end

    def lock_acquired?
      lock_acquired
    end

    private

    attr_reader :service, :lock_acquired, :key, :owner

    def build_lock_request
      Models::LockRequest.new(
        {
          resource: {
            key: key,
            owner: owner,
            type_code: Models::TypeCode::LOCK
          },
          ttl_in_seconds: 15
        }
      )
    end

    def logger
      @logger ||= Steno.logger('cc.locket-client')
    end
  end
end
