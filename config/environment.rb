require File.expand_path('application', __dir__)

Rails.logger = Logger.new('/dev/null')
Rails.application.initialize!
