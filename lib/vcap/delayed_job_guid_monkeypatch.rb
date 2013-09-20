require "delayed_job_sequel"
require "securerandom"

class Delayed::Job
  #before_create :add_guid
  #
  #private
  #def add_guid
  #  self.guid = SecureRandom.uuid
  #end
end