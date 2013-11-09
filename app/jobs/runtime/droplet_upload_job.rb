class DropletUploadJob < Struct.new(:local_path, :app_id)
  def perform
    app = VCAP::CloudController::App[id: app_id]

    if app
      blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
      CloudController::DropletUploader.new(app, blobstore).upload(local_path)
    end

    FileUtils.rm_f(local_path)
  end

  def error(job, _)
    if job.attempts == max_attempts - 1 && File.exists?(local_path)
      FileUtils.rm_f(local_path)
    end
  end

  def max_attempts
    3
  end
end

__END__
    #logger.info "droplet.begin-upload", :app_guid => app.guid
    #start = Time.now

    #logger.info "droplet.uploaded", took: Time.now - start, :app_guid => app.guid
    #logger.info "droplet.saved", :sha => app.droplet_hash, :app_guid => app.guid
