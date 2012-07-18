# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    # some objects already have an index on :name by itself
    # spaces and apps only have one as part of a compound index with the name
    # listed last, so we need an explicit index to make the queries efficient.
    [:spaces, :apps].each do |t|
      alter_table t do
        add_index :name
      end
    end
  end
end
