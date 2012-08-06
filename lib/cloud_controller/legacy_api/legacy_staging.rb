# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyStaging < LegacyApiBase
    include VCAP::CloudController::Errors

    class DropletUploadHandle
      attr_accessor :id, :upload_path

      def initialize(id)
        @id = id
        @upload_path = nil
      end
    end

    class << self
      def configure(config)
        @config = config
      end

      def download_app_uri(id)
        staging_uri("/staging/app/#{id}")
      end

      def upload_droplet_uri(id)
        staging_uri("/staging/app/#{id}")
      end

      def with_upload_handle(id)
        handle = create_handle(id)
        yield handle
      ensure
        destroy_handle handle
      end

      private

      def staging_uri(path)
        URI::HTTP.build(
          :host     => @config[:bind_address],
          :port     => @config[:port],
          :userinfo => [@config[:staging][:auth][:user], @config[:staging][:auth][:password]],
          :path     => path
        ).to_s
      end

      def upload_handles
        @upload_handles ||= {}
      end

      def create_handle(id)
        handle = DropletUploadHandle.new(id)
        mutex.synchronize do
          if upload_handles[id]
            raise Errors::StagingError.new("staging already in progress for #{id}")
          end
          upload_handles[handle.id] = handle
        end
        handle
      end

      def destroy_handle(handle)
        return unless handle
        mutex.synchronize do
          upload_handles.delete(handle.id)
        end
      end

      MUTEX = Mutex.new
      def mutex
        MUTEX
      end

      def logger
        @logger ||= Steno.logger("cc.legacy_staging")
      end
    end

    # Handles an app download from a stager
    def download_app(id)
      app = Models::App.find(:guid => id)
      raise AppNotFound.new(id) if app.nil?

      package_path = AppPackage.package_path(id)
      logger.debug "id: #{id} package_path: #{package_path}"

      unless File.exist?(package_path)
        logger.error "could not find package for #{id}"
        raise AppPackageNotFound.new(id)
      end

      # TODO: enable nginx
      # response.headers['X-Accel-Redirect'] = '/droplets/' + File.basename(path)
      # render :nothing => true, :status => 200
      send_file package_path
    end

    get "/staging/app/:id", :download_app
  end
end
