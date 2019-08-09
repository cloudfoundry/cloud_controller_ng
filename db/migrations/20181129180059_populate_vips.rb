Sequel.migration do
  up do
    self[:routes].order(:id).each_with_index do |route, i|
      next unless self[:domains].filter(id: route[:domain_id])[:internal]

      self[:routes].filter(guid: route[:guid]).update(vip_offset: (i + 1).to_i)
    end
  end
end
