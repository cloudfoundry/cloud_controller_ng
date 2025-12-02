module Vmstat
  # Since on linux the type and mount information are note available in the
  # statfs library, we have to use constants to find out the file system type.
  # The mount point and the path will allways be the same, because we don't have
  # the mount information. But one can still either use the device or mountpoint
  # to get the information.
  class LinuxDisk < Disk
    # Mapping of file system type codes to file system names.
    FS_CODES = {
      44533=>:adfs, 44543=>:affs, 1111905073=>:befs, 464386766=>:bfs,
      4283649346=>:cifs_number, 1937076805=>:coda, 19920823=>:coh,
      684539205=>:cramfs, 4979=>:devfs, 4278867=>:efs, 4989=>:ext,
      61265=>:ext2_old, 61267=>:ext4, 16964=>:hfs, 4187351113=>:hpfs,
      2508478710=>:hugetlbfs, 38496=>:isofs, 29366=>:jffs2,
      827541066=>:jfs, 4991=>:minix, 9320=>:minix2, 9336=>:minix22,
      19780=>:msdos, 22092=>:ncp, 26985=>:nfs, 1397118030=>:ntfs_sb,
      40865=>:openprom, 40864=>:proc, 47=>:qnx4, 1382369651=>:reiserfs,
      29301=>:romfs, 20859=>:smb, 19920822=>:sysv2, 19920821=>:sysv4,
      16914836=>:tmpfs, 352400198=>:udf, 72020=>:ufs, 7377 => :devpts,
      40866=>:usbdevice, 2768370933=>:vxfs, 19920820=>:xenix, 1481003842=>:xfs,
      19911021=>:xiafs, 1448756819=>:reiserfs, 1650812274 => :sysfs
    }.freeze

    # Mainly a wrapper for the {Vmstat::Disk} class constructor. This constructor
    # handles the file system type mapping (based on the magic codes defined in
    # {LinuxDisk::FS_CODES}).
    # @param [Fixnum] fs the type or magix number of the disk.
    # @param [String] path the path to the disk
    # @param [Fixnum] block_size size of a file system block
    # @param [Fixnum] free_blocks the number of free blocks
    # @param [Fixnum] available_blocks the number of available blocks
    # @param [Fixnum] total_blocks the number of total blocks
    def initialize(fs = nil, path = nil, block_size = nil, free_blocks = nil,
                   available_blocks = nil, total_blocks = nil)
      @fs = fs
      super FS_CODES[@fs], path, path, block_size, 
            free_blocks, available_blocks, total_blocks
    end
  end
end
