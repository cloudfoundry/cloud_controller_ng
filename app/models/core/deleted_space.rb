module VCAP::CloudController
  class DeletedSpace
    def guid
      ""
    end

    def organization
      Struct.new(:guid).new("")
    end
  end
end