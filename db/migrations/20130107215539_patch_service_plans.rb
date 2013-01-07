# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    self[:service_plans].all do |plan|
      if plan[:name] =~ /^d?1[0-9][0-9]$/i
        self[:service_plans].filter(:id => plan[:id]).update(:free => true)
      end
    end
  end
end
