unless ENV['DISABLE_COVERAGE'] == 'true'
  require 'coveralls'
  require 'timecop'
  Coveralls.wear!
end
