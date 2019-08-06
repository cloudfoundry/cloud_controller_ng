module TimeHelpers
  include VCAP::CloudController

  def iso8601
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
  end

  # https://gist.github.com/marcelotmelo/b67f58a08bee6c2468f8
  def rfc3339
    /^([0-9]+)-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])[Tt]([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9]|60)(\.[0-9]+)?(([Zz])|([\+|\-]([01][0-9]|2[0-3]):[0-5][0-9]))$/
  end
end
