require File.expand_path('application', __dir__)

Rails.logger = Logger.new(File::NULL)
Rails.application.initialize!
