Sequel.migration do
  up do
    self[:services].filter(provider: nil).all.each do |service|
      if self[:services].filter(label: service.label, provider: '').first
        service.update(label: "#{service.label}-#{service.id}", provider: '')
      else
        service.update(provider: '')
      end
    end

    alter_table :services do
      set_column_default :provider, ''
      set_column_not_null :provider
    end
  end

  down do
    alter_table :services do
      set_column_allow_null :provider
      set_column_default :provider, nil
    end

    self[:services].filter(provider: '').all.each do |service|
      service.update(provider: nil)
    end
  end
end
