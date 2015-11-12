require File.expand_path('../application', __FILE__)

Rails.logger = Logger.new('/dev/null')
Rails.application.initialize!
