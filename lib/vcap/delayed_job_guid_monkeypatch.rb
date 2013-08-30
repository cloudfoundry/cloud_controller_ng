require "delayed_job_active_record"
require "securerandom"

class Delayed::Job
  before_create :add_guid

  private
  def add_guid
    self.guid = SecureRandom.uuid
  end
end