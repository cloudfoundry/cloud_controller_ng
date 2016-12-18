class Service < Sequel::Model
end

Sequel.migration do
  up do
    Service.filter(provider: nil).all.each do |service|
      if Service.filter(label: service.label, provider: '').first
        service.update(label: "#{service.label}-#{service.id}", provider: '')
      else
        service.update(provider: '')
      end
    end

    alter_table :services do
      drop_index [:label, :provider]
      set_column_default :provider, ''
      set_column_not_null :provider
      add_index [:label, :provider], unique: true
    end
  end

  down do
    alter_table :services do
      drop_index [:label, :provider]
      set_column_allow_null :provider
      set_column_default :provider, nil
      add_index [:label, :provider], unique: true
    end

    Service.filter(provider: '').all.each do |service|
      service.update(provider: nil)
    end
  end
end
