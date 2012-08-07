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

      def lookup_handle(id)
        mutex.synchronize do
          return upload_handles[id]
        end
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
          if handle.upload_path && File.exists?(handle.upload_path)
            File.delete(handle.upload_path)
          end
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

    # Handles a droplet upload from a stager
    def upload_droplet(id)
      app = Models::App.find(:guid => id)
      raise AppNotFound.new(id) if app.nil?

      handle = self.class.lookup_handle(id)
      raise StagingError.new("staging not in progress for #{id}") unless handle
      raise StagingError.new("malformed droplet upload request for #{id}") unless upload_file

      upload_path = upload_file.path
      final_path = save_path(id)
      logger.debug "renaming staged droplet from '#{upload_path}' to '#{final_path}'"

      begin
        File.rename(upload_path, final_path)
      rescue => e
        raise StagingError.new("failed renaming staged droplet: #{e}")
      end

      handle.upload_path = final_path
      logger.debug "uploaded droplet for #{id} to #{final_path}"
      HTTP::OK
    end

    private

    def upload_file
      # TODO: enable nginx
      # if CloudController.use_nginx
      #   params[:droplet_path]
      # else
      @upload_file ||= params["upload"]["droplet"][:tempfile]
    rescue
      nil
    end

    def save_path(id)
      File.join(tmpdir, "staged_upload_#{id}.tgz")
    end

    def tmpdir
      (config[:directories] && config[:directories][:tmpdir]) || Dir.tmpdir
    end

    controller.before "/staging/app/*" do
      auth =  Rack::Auth::Basic::Request.new(env)
      unless (auth.provided? && auth.basic? && auth.credentials &&
              auth.credentials == [@config[:staging][:auth][:user],
                                   @config[:staging][:auth][:password]])
        raise NotAuthorized
      end
    end

    get  "/staging/app/:id", :download_app
    post "/staging/app/:id", :upload_droplet
  end
end
