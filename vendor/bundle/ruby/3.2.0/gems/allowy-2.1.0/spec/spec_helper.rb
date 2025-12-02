require 'pry'
require 'its'
require 'allowy'
require 'allowy/matchers'

RSpec.configure do |c|
  c.run_all_when_everything_filtered = true
  c.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end

class SampleAccess
  include Allowy::AccessControl

  def read?(str)
    str == 'allow'
  end

  def early_deny?(str)
    deny! "early terminate: #{str}"
  end

  def extra_params?(foo, *opts)
    foo == opts.last[:bar]
  end

  def context_is_123?(*whatever)
    context === 123
  end
end

class SamplePermission
  include Allowy::AccessControl
end

class Sample
  attr_accessor :name
end
