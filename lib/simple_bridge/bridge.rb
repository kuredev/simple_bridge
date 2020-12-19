require "socket"

class SimpleBridge::Bridge
  SOL_PACKET            = 0x0107 # bits/socket.h
  IFINDEX_SIZE          = 0x0004 # sizeof(ifreq.ifr_ifindex) on 64bit
  IFREQ_SIZE            = 0x0028 # sizeof(ifreq) on 64bit
  SIOCGIFINDEX          = 0x8933 # bits/ioctls.h
  PACKET_MR_PROMISC     = 0x0001 # netpacket/packet.h
  PACKET_MREQ_SIZE      = 0x0010 # sizeof(packet_mreq) on 64bit
  PACKET_ADD_MEMBERSHIP = 0x0001 # netpacket/packet.h
  ETH_P_ALL = [ 0x0003 ].pack('S>').unpack('S').first # linux/if_ether.h, needs to be native-endian uint16_t

  # constructor
  #
  # @param interface1 [String]
  # @param interface2 [String]
  def initialize(interface1, interface2)
    @interface1 = interface1
    @interface2 = interface2
  end

  # Run as a bridge until Ctrl + C.
  def run
    sock1 = Socket.new(Socket::AF_PACKET, Socket::SOCK_RAW, ETH_P_ALL)
    sock2 = Socket.new(Socket::AF_PACKET, Socket::SOCK_RAW, ETH_P_ALL)

    bind_if(sock1, @interface1)
    bind_if(sock2, @interface2)

    promiscuous(sock1, @interface1)
    promiscuous(sock2, @interface2)

    sock1_object_id = sock1.object_id
    sock2_object_id = sock2.object_id
    while true
      ret = IO::select([sock1, sock2])
      ret[0].each do |sock|
        payload = sock.recv(65535)
        sock_send = sock.object_id === sock1_object_id ? sock2 : sock1
        sock_send.send(payload, 0)
      end
    end
  end

  private

  def bind_if(socket, interface)
    ifreq = [ interface, '' ].pack('a16a16')

    socket.ioctl(SIOCGIFINDEX, ifreq)
    index_str = ifreq[16, 4]

    eth_p_all_hbo = [ ETH_P_ALL ].pack('S').unpack('S>').first
    sll = [ Socket::AF_PACKET, eth_p_all_hbo, index_str ].pack('SS>a16')
    socket.bind(sll)
  end

  def promiscuous(socket, interface)
    ifreq = [interface].pack('a' + IFREQ_SIZE.to_s)
    socket.ioctl(SIOCGIFINDEX, ifreq)
    if_num = ifreq[Socket::IFNAMSIZ, IFINDEX_SIZE]
    mreq = if_num.dup
    mreq << [PACKET_MR_PROMISC].pack('s')
    mreq << ("\x00" * (PACKET_MREQ_SIZE - mreq.length))
    socket.setsockopt(SOL_PACKET, PACKET_ADD_MEMBERSHIP, mreq)
  end
end
