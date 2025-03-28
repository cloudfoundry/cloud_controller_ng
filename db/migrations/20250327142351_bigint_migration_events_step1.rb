require File.expand_path('../helpers/bigint_migration', __dir__)

Sequel.migration do
  up do
    unless opt_out?
      if empty?(:events)
        change_pk_to_bigint(:events)
      else
        add_bigint_column(:events)
      end
    end
  end

  down do
    revert_pk_to_integer(:events)
    drop_bigint_column(:events)
  end
end
