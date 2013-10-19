require "jobs/runtime/app_bits_packer_job"
require "jobs/runtime/droplet_deletion_job"
require "jobs/runtime/blobstore_upload"

class LocalQueue < Struct.new(:config)
  def to_s
    "cc-#{config[:name]}-#{config[:index]}"
  end
end