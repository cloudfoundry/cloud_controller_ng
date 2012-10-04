# Copyright (c) 2009-2012 VMware, Inc.

module VCAP
  module SequelVarz
    def self.start(db)
      return if @db
      @db = db

      Thread.new do
        while true
          update_varz
          sleep 1
        end
      end
    end

    private

    def self.update_varz
      h = sequel_varz
      VCAP::Component.varz.synchronize do
        VCAP::Component.varz[:vcap_sequel] = h
      end
    end

    def self.sequel_varz
      {
        "connection_pool" => {
          "size" => @db.pool.size,
          "max_size" => @db.pool.max_size,
          "allocated" => @db.pool.allocated.size,
          "available" => @db.pool.available_connections.size
        }
      }
    end

    def self.logger
      @logger ||= Steno.logger("sequel.varz")
    end
  end
end
