module VCAP::CloudController
  class Droplet < Sequel::Model
    many_to_one :app

    def validate
      validates_presence :app
      validates_presence :droplet_hash
    end
  end
end