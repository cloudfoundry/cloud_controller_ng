# Reverted this migration 12e3e8a08591fe5bd3e29505c51a2124500cc73f
# Originally this migration was to remove the space_id column but there was a previous migration
# in CF 213 that did the same thing incorrectly, which was altered in CF 214. When this migration file
# was written, it conflicted with the environments that had deployed CF 213 at some point in time. We reverted
# this migration pending a future conditional migration. This is here as a stub for environments that had
# run this migration file before reverting.
Sequel.migration do
  up do
  end

  down do
  end
end


