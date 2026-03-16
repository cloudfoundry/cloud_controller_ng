# frozen_string_literal: true

# Lightweight spec helper for allowy tests
# Does not require database connection or full CCNG stack

require 'rspec'
require 'allowy/allowy'

# Test fixtures
class SampleAccess
  include Allowy::AccessControl

  def read?(str)
    str == 'allow'
  end

  def early_deny?(str)
    deny!("early terminate: #{str}")
  end

  def extra_params?(foo, *opts)
    foo == opts.last[:bar]
  end

  def context_is_123?(*_whatever)
    context == 123
  end
end

class SamplePermission
  include Allowy::AccessControl
end

class Sample
  attr_accessor :name
end
