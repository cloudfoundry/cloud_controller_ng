module TimeHelpers
  include VCAP::CloudController

  def iso8601
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
  end
end
