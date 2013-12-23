require "jobs/runtime/app_bits_packer"
require "jobs/runtime/blobstore_delete"
require "jobs/runtime/blobstore_upload"
require "jobs/runtime/droplet_deletion"
require "jobs/runtime/droplet_upload_job"
require "jobs/runtime/model_deletion_job"
require "jobs/runtime/legacy_jobs"

class LocalQueue < Struct.new(:config)
  def to_s
    "cc-#{config[:name]}-#{config[:index]}"
  end
end
