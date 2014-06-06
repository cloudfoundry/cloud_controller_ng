module VCAP::CloudController
  class TestModel < Sequel::Model; end
  class TestModelDestroyDep < Sequel::Model; end
  class TestModelNullifyDep < Sequel::Model; end

  class TestModelAccess < BaseAccess; end
  class TestModelDestroyDepAccess < BaseAccess; end
  class TestModelNullifyDepAccess < BaseAccess; end
end
