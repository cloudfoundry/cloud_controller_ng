require 'machinist/sequel'

raise 'Tear down this monkey patch!' unless Machinist.const_defined?('SequelExtensions')

module Machinist::SequelExtensions::ClassMethods
  def returning(value)
    yield(value)
    value
  end
end
