module Vmstat
  def self.cpu
    cptime = `sysctl kern.cp_time`.split(/=/).last
    user, nice, sys, irq, idle = cptime.split(/,/).map(&:to_i)
    [Cpu.new(0, user, sys + irq, nice, idle)]
  end
  
  def self.memory
    uvmexp = `vmstat -s`

    Memory.new(
      # pagesize call is not used to avoid double shell out
      pagesize,       # pagesize
      extract_uvm_val(uvmexp, 'pages managed'),        # wired
      extract_uvm_val(uvmexp, 'pages active'),         # active
      extract_uvm_val(uvmexp, 'pages inactive'),       # inactive
      extract_uvm_val(uvmexp, 'pages free'),           # free
      extract_uvm_val(uvmexp, 'pagein operations'),    # pageins
      extract_uvm_val(uvmexp, 'pages being paged out') # pageouts
    )
  end

  def self.network_interfaces
    bytes = `netstat -ibq`.lines.grep(/<Link>/) # bytes
    pkgs = `netstat -iqd`.lines.grep(/<Link>/) # packages
  
    itf = Hash.new { |h, k| h[k] = NetworkInterface.new(k) }
  
    bytes.each do |line|
      # Name Mtu Network Address Ibytes Obytes
      name, _, _, _, ibytes, obytes = line.split(/\s+/)
      itf[name].in_bytes = ibytes.to_i
      itf[name].out_bytes = obytes.to_i
    end
  
    pkgs.each do |line| 
      # Name Mtu Network Address Ipkts Ierrs Opkts Oerrs Colls Drop
      name, _, _, _, _, ierrs, _, oerrs, _, drop = line.split(/\s+/)
      itf[name].in_errors = ierrs.to_i
      itf[name].in_drops = drop.to_i
      itf[name].out_errors = oerrs.to_i
    end
    
    itf.each do |name, nic|
      if name =~ /lo\d+/ 
        nic.type = NetworkInterface::LOOPBACK_TYPE
      else
        nic.type = NetworkInterface::ETHERNET_TYPE
      end
    end
  
    itf.values      
  end

  def self.extract_uvm_val(uvmexp, name)
    regexp = Regexp.new('(\d+)\s' + name)
    uvmexp.lines.grep(regexp) do |line|
      return $1.to_i
    end
  end
end
