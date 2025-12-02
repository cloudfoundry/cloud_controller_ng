require 'spec_helper'

describe Vmstat::Solaris do
  let(:solaris) do
    c = Vmstat::Solaris
    
    def c.`(cmd)
      if cmd == 'kstat -p "cpu_stat:::/idle|kernel|user/"'
        "cpu_stat:0:cpu_stat0:idle       2325343762
cpu_stat:0:cpu_stat0:idlethread 776439232
cpu_stat:0:cpu_stat0:kernel     89137335
cpu_stat:0:cpu_stat0:kernel_asflt       1
cpu_stat:0:cpu_stat0:user       64919001
cpu_stat:1:cpu_stat1:idle       2322767706
cpu_stat:1:cpu_stat1:idlethread 125993797
cpu_stat:1:cpu_stat1:kernel     78457429
cpu_stat:1:cpu_stat1:kernel_asflt       34
cpu_stat:1:cpu_stat1:user       78174710
cpu_stat:2:cpu_stat2:idle       2390178542
cpu_stat:2:cpu_stat2:idlethread 3368087417
cpu_stat:2:cpu_stat2:kernel     50617796
cpu_stat:2:cpu_stat2:kernel_asflt       0
cpu_stat:2:cpu_stat2:user       38603497
cpu_stat:3:cpu_stat3:idle       2390802861
cpu_stat:3:cpu_stat3:idlethread 1772145290
cpu_stat:3:cpu_stat3:kernel     46044221
cpu_stat:3:cpu_stat3:kernel_asflt       0
cpu_stat:3:cpu_stat3:user       42552751
cpu_stat:4:cpu_stat4:idle       2436590263
cpu_stat:4:cpu_stat4:idlethread 2145015281
cpu_stat:4:cpu_stat4:kernel     23983506
cpu_stat:4:cpu_stat4:kernel_asflt       0
cpu_stat:4:cpu_stat4:user       18826062
cpu_stat:5:cpu_stat5:idle       2435969240
cpu_stat:5:cpu_stat5:idlethread 3720145695
cpu_stat:5:cpu_stat5:kernel     25630307
cpu_stat:5:cpu_stat5:kernel_asflt       0
cpu_stat:5:cpu_stat5:user       17800281
cpu_stat:6:cpu_stat6:idle       2432659504
cpu_stat:6:cpu_stat6:idlethread 3012624014
cpu_stat:6:cpu_stat6:kernel     24414413
cpu_stat:6:cpu_stat6:kernel_asflt       0
cpu_stat:6:cpu_stat6:user       22325909
cpu_stat:7:cpu_stat7:idle       2430409364
cpu_stat:7:cpu_stat7:idlethread 1931519381
cpu_stat:7:cpu_stat7:kernel     28094309
cpu_stat:7:cpu_stat7:kernel_asflt       0
cpu_stat:7:cpu_stat7:user       20896150
cpu_stat:8:cpu_stat8:idle       2443187236
cpu_stat:8:cpu_stat8:idlethread 1900014542
cpu_stat:8:cpu_stat8:kernel     20799721
cpu_stat:8:cpu_stat8:kernel_asflt       0
cpu_stat:8:cpu_stat8:user       15412864
cpu_stat:9:cpu_stat9:idle       2440596009
cpu_stat:9:cpu_stat9:idlethread 3703869451
cpu_stat:9:cpu_stat9:kernel     23787482
cpu_stat:9:cpu_stat9:kernel_asflt       0
cpu_stat:9:cpu_stat9:user       15016328
cpu_stat:10:cpu_stat10:idle     2427567910
cpu_stat:10:cpu_stat10:idlethread       3191481058
cpu_stat:10:cpu_stat10:kernel   30059932
cpu_stat:10:cpu_stat10:kernel_asflt     5
cpu_stat:10:cpu_stat10:user     21771975
cpu_stat:11:cpu_stat11:idle     2431827979
cpu_stat:11:cpu_stat11:idlethread       1824361353
cpu_stat:11:cpu_stat11:kernel   27388335
cpu_stat:11:cpu_stat11:kernel_asflt     0
cpu_stat:11:cpu_stat11:user     20183500
cpu_stat:12:cpu_stat12:idle     2442824569
cpu_stat:12:cpu_stat12:idlethread       2037054756
cpu_stat:12:cpu_stat12:kernel   21276397
cpu_stat:12:cpu_stat12:kernel_asflt     0
cpu_stat:12:cpu_stat12:user     15298846
cpu_stat:13:cpu_stat13:idle     2443388458
cpu_stat:13:cpu_stat13:idlethread       3442886390
cpu_stat:13:cpu_stat13:kernel   22081759
cpu_stat:13:cpu_stat13:kernel_asflt     0
cpu_stat:13:cpu_stat13:user     13929592
cpu_stat:14:cpu_stat14:idle     2434768696
cpu_stat:14:cpu_stat14:idlethread       2856867656
cpu_stat:14:cpu_stat14:kernel   23352419
cpu_stat:14:cpu_stat14:kernel_asflt     0
cpu_stat:14:cpu_stat14:user     21278693
cpu_stat:15:cpu_stat15:idle     2432514522
cpu_stat:15:cpu_stat15:idlethread       1703823954
cpu_stat:15:cpu_stat15:kernel   27050642
cpu_stat:15:cpu_stat15:kernel_asflt     16
cpu_stat:15:cpu_stat15:user     19834642
cpu_stat:16:cpu_stat16:idle     2436582325
cpu_stat:16:cpu_stat16:idlethread       1983802071
cpu_stat:16:cpu_stat16:kernel   21833225
cpu_stat:16:cpu_stat16:kernel_asflt     0
cpu_stat:16:cpu_stat16:user     20984253
cpu_stat:17:cpu_stat17:idle     2432250902
cpu_stat:17:cpu_stat17:idlethread       307297399
cpu_stat:17:cpu_stat17:kernel   29580663
cpu_stat:17:cpu_stat17:kernel_asflt     0
cpu_stat:17:cpu_stat17:user     17568236
cpu_stat:18:cpu_stat18:idle     2447310538
cpu_stat:18:cpu_stat18:idlethread       1473510287
cpu_stat:18:cpu_stat18:kernel   18480841
cpu_stat:18:cpu_stat18:kernel_asflt     5
cpu_stat:18:cpu_stat18:user     13608419
cpu_stat:19:cpu_stat19:idle     2446462748
cpu_stat:19:cpu_stat19:idlethread       2882237650
cpu_stat:19:cpu_stat19:kernel   20384068
cpu_stat:19:cpu_stat19:kernel_asflt     0
cpu_stat:19:cpu_stat19:user     12552980
cpu_stat:20:cpu_stat20:idle     2439710143
cpu_stat:20:cpu_stat20:idlethread       2513415319
cpu_stat:20:cpu_stat20:kernel   20976077
cpu_stat:20:cpu_stat20:kernel_asflt     0
cpu_stat:20:cpu_stat20:user     18713575
cpu_stat:21:cpu_stat21:idle     2434565830
cpu_stat:21:cpu_stat21:idlethread       1574993351
cpu_stat:21:cpu_stat21:kernel   26063716
cpu_stat:21:cpu_stat21:kernel_asflt     0
cpu_stat:21:cpu_stat21:user     18770245
cpu_stat:22:cpu_stat22:idle     2447896586
cpu_stat:22:cpu_stat22:idlethread       1566290884
cpu_stat:22:cpu_stat22:kernel   18718466
cpu_stat:22:cpu_stat22:kernel_asflt     0
cpu_stat:22:cpu_stat22:user     12784738
cpu_stat:23:cpu_stat23:idle     2444823222
cpu_stat:23:cpu_stat23:idlethread       3286395080
cpu_stat:23:cpu_stat23:kernel   21510594
cpu_stat:23:cpu_stat23:kernel_asflt     0
cpu_stat:23:cpu_stat23:user     13065972
cpu_stat:24:cpu_stat24:idle     2437316848
cpu_stat:24:cpu_stat24:idlethread       2628739060
cpu_stat:24:cpu_stat24:kernel   22266295
cpu_stat:24:cpu_stat24:kernel_asflt     0
cpu_stat:24:cpu_stat24:user     19816643
cpu_stat:25:cpu_stat25:idle     2433451000
cpu_stat:25:cpu_stat25:idlethread       1604646150
cpu_stat:25:cpu_stat25:kernel   26748441
cpu_stat:25:cpu_stat25:kernel_asflt     0
cpu_stat:25:cpu_stat25:user     19200341
cpu_stat:26:cpu_stat26:idle     2446405472
cpu_stat:26:cpu_stat26:idlethread       1573139378
cpu_stat:26:cpu_stat26:kernel   19619834
cpu_stat:26:cpu_stat26:kernel_asflt     0
cpu_stat:26:cpu_stat26:user     13374474
cpu_stat:27:cpu_stat27:idle     2444019515
cpu_stat:27:cpu_stat27:idlethread       3275705315
cpu_stat:27:cpu_stat27:kernel   21816225
cpu_stat:27:cpu_stat27:kernel_asflt     0
cpu_stat:27:cpu_stat27:user     13564039
cpu_stat:28:cpu_stat28:idle     2435784523
cpu_stat:28:cpu_stat28:idlethread       2628201319
cpu_stat:28:cpu_stat28:kernel   23125551
cpu_stat:28:cpu_stat28:kernel_asflt     0
cpu_stat:28:cpu_stat28:user     20489701
cpu_stat:29:cpu_stat29:idle     2432230501
cpu_stat:29:cpu_stat29:idlethread       1635408506
cpu_stat:29:cpu_stat29:kernel   27198273
cpu_stat:29:cpu_stat29:kernel_asflt     0
cpu_stat:29:cpu_stat29:user     19970999
cpu_stat:30:cpu_stat30:idle     2444413183
cpu_stat:30:cpu_stat30:idlethread       1644573224
cpu_stat:30:cpu_stat30:kernel   20310412
cpu_stat:30:cpu_stat30:kernel_asflt     0
cpu_stat:30:cpu_stat30:user     14676176
cpu_stat:31:cpu_stat31:idle     2442483106
cpu_stat:31:cpu_stat31:idlethread       3345414215
cpu_stat:31:cpu_stat31:kernel   22515695
cpu_stat:31:cpu_stat31:kernel_asflt     0
cpu_stat:31:cpu_stat31:user     14400967\n"
      elsif cmd == "kstat -p unix:::boot_time"
        "unix:0:system_misc:boot_time     1470765992\n"
      elsif cmd == "kstat -p -n system_pages"
        "unix:0:system_pages:availrmem     70121
unix:0:system_pages:crtime        116.1198523
unix:0:system_pages:desfree       3744
unix:0:system_pages:desscan       25
unix:0:system_pages:econtig       176160768
unix:0:system_pages:fastscan      137738
unix:0:system_pages:freemem       61103
unix:0:system_pages:kernelbase    16777216
unix:0:system_pages:lotsfree      7488
unix:0:system_pages:minfree       1872
unix:0:system_pages:nalloc        26859076
unix:0:system_pages:nalloc_calls  11831
unix:0:system_pages:nfree         25250198
unix:0:system_pages:nfree_calls   7888
unix:0:system_pages:nscan         0
unix:0:system_pages:pagesfree     61103
unix:0:system_pages:pageslocked   409145
unix:0:system_pages:pagestotal    479266
unix:0:system_pages:physmem       489586
unix:0:system_pages:pp_kernel     438675
unix:0:system_pages:slowscan      100
unix:0:system_pages:snaptime      314313.3248461\n"
      elsif cmd == "kstat -p link:::"
        "link:0:e1000g0:ierrors 0
link:0:e1000g0:oerrors 1
link:0:e1000g0:rbytes64 1000
link:0:e1000g0:obytes64 2000\n"
      else
        raise "Unknown cmd: '#{cmd}'"
      end
    end
    c
  end
  
  context "#cpu" do
    subject { solaris.cpu }

    it { should be_a(Array)}
    it do
      should == [
        Vmstat::Cpu.new(0, 64919001, 89137335, 0, 2325343762),
        Vmstat::Cpu.new(1, 78174710, 78457429, 0, 2322767706),
        Vmstat::Cpu.new(2, 38603497, 50617796, 0, 2390178542),
        Vmstat::Cpu.new(3, 42552751, 46044221, 0, 2390802861),
        Vmstat::Cpu.new(4, 18826062, 23983506, 0, 2436590263),
        Vmstat::Cpu.new(5, 17800281, 25630307, 0, 2435969240),
        Vmstat::Cpu.new(6, 22325909, 24414413, 0, 2432659504),
        Vmstat::Cpu.new(7, 20896150, 28094309, 0, 2430409364),
        Vmstat::Cpu.new(8, 15412864, 20799721, 0, 2443187236),
        Vmstat::Cpu.new(9, 15016328, 23787482, 0, 2440596009),
        Vmstat::Cpu.new(10, 21771975, 30059932, 0, 2427567910),
        Vmstat::Cpu.new(11, 20183500, 27388335, 0, 2431827979),
        Vmstat::Cpu.new(12, 15298846, 21276397, 0, 2442824569),
        Vmstat::Cpu.new(13, 13929592, 22081759, 0, 2443388458),
        Vmstat::Cpu.new(14, 21278693, 23352419, 0, 2434768696),
        Vmstat::Cpu.new(15, 19834642, 27050642, 0, 2432514522),
        Vmstat::Cpu.new(16, 20984253, 21833225, 0, 2436582325),
        Vmstat::Cpu.new(17, 17568236, 29580663, 0, 2432250902),
        Vmstat::Cpu.new(18, 13608419, 18480841, 0, 2447310538),
        Vmstat::Cpu.new(19, 12552980, 20384068, 0, 2446462748),
        Vmstat::Cpu.new(20, 18713575, 20976077, 0, 2439710143),
        Vmstat::Cpu.new(21, 18770245, 26063716, 0, 2434565830),
        Vmstat::Cpu.new(22, 12784738, 18718466, 0, 2447896586),
        Vmstat::Cpu.new(23, 13065972, 21510594, 0, 2444823222),
        Vmstat::Cpu.new(24, 19816643, 22266295, 0, 2437316848),
        Vmstat::Cpu.new(25, 19200341, 26748441, 0, 2433451000),
        Vmstat::Cpu.new(26, 13374474, 19619834, 0, 2446405472),
        Vmstat::Cpu.new(27, 13564039, 21816225, 0, 2444019515),
        Vmstat::Cpu.new(28, 20489701, 23125551, 0, 2435784523),
        Vmstat::Cpu.new(29, 19970999, 27198273, 0, 2432230501),
        Vmstat::Cpu.new(30, 14676176, 20310412, 0, 2444413183),
        Vmstat::Cpu.new(31, 14400967, 22515695, 0, 2442483106)
      ]
    end
  end

  context "#memory" do
    subject { solaris.memory }

    it { should be_a(Vmstat::Memory) }
    if `getconf PAGESIZE`.chomp.to_i == 4096
      it do
        should == Vmstat::Memory.new(4096, 409145, 9018, 0, 61103, 0, 0)
      end
    end
  end

  context "#boot_time" do
    subject { solaris.boot_time }

    it { should be_a(Time) }
    it { should == Time.at(1470765992) }
  end

  context "#network_interfaces" do
    subject { solaris.network_interfaces }

    it { should be_a(Array) }
    it do
      should == [
        Vmstat::NetworkInterface.new(:e1000g0, 1000, 0, 0, 2000, 1,
                                     Vmstat::NetworkInterface::ETHERNET_TYPE)
      ]
    end
  end
end
