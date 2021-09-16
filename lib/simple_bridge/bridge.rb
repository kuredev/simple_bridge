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

        # ★ここでプロトコルを解析する
        ### ★★ 動作確認してみる -> 動きそう。
        recv_mesg = SimpleBridge::RecvMessage.new(payload)
        puts "----protocol"
        pp recv_mesg.protocol

        sock_send = sock.object_id === sock1_object_id ? sock2 : sock1
        sock_send.send(payload, 0)
      end
    end
  end

  private

  # RAWソケット用のbind
  #  というよりは AF_PACKET(L2)のbindかな。
  def bind_if(socket, interface)
    ifreq = [ interface, '' ].pack('a16a16')

    socket.ioctl(SIOCGIFINDEX, ifreq)
    index_str = ifreq[16, 4]

    eth_p_all_hbo = [ ETH_P_ALL ].pack('S').unpack('S>').first
    # S>:  big endian unsigned 16bit(nと同じ)
    # sockaddr_ll
    sll = [ Socket::AF_PACKET, eth_p_all_hbo, index_str ].pack('SS>a16') # sockaddr_ll
    puts "---bind_if: #{interface}"
    pp sll # \x11\x00\x00\x03\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
    # puts "----sll"
    # pp sll.length # 20
    socket.bind(sll)
  end

  def promiscuous(socket, interface)
    ifreq = [interface].pack('a' + IFREQ_SIZE.to_s)
    puts "==ifreq"
    pp ifreq # "eth1\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
    socket.ioctl(SIOCGIFINDEX, ifreq)

    if_num = ifreq[Socket::IFNAMSIZ, IFINDEX_SIZE]
    puts "==if_num"
    pp if_num # "\x03\x00\x00\x00"
    mreq = if_num.dup
    mreq << [PACKET_MR_PROMISC].pack('s')
    mreq << ("\x00" * (PACKET_MREQ_SIZE - mreq.length))
    # setsockopt(level, optname, optval)
    # levelは、指定したオプションを解釈するシステム内のコード、すなわち一般的なソケットのコードかプロトコル依存のコード(例えばIPv4、IPv6あるいはTCP)を指定する。
    # パケットソケットのオプションは、レベル SOL_PACKET を指定して setsockopt(2) を呼び出すことで設定できる。
    #  SOL_PACKETは本には解説は無い。
    #   PACKET_ADD_MEMBERSHIP
    #   PACKET_DROP_MEMBERSHIP
    #   packet ソケットは、物理層のマルチキャストや 無差別モード (promiscuous mode) を設定して使うことができる。
    #   定義見つけた
    #     % cat /usr/include/bits/socket.h | grep SOL_PA
    #     define SOL_PACKET      263
    # optname は PACKET_ADD_MEMBERSHIP
    # % cat /usr/include/netpacket/packet.h | grep ADD
    # define PACKET_ADD_MEMBERSHIP           1
    # これらはいずれも packet_mreq 構造体を引き数に取る。 https://linuxjm.osdn.jp/html/LDP_man-pages/man7/packet.7.html
    # optval に packet_mreq 構造体を渡す方法を考える。。
    # ★ https://docs.ruby-lang.org/ja/latest/method/BasicSocket/i/setsockopt.html
    # へんみると構造体のメンバ (https://docs.oracle.com/cd/E19455-01/806-2730/sockets-5/index.html)
    # のバイトオーダーを文字列で結合したものを渡せばよい？
    # この例でも optval は本来構造体を受け取るところ、文字列（.hton）を渡している
    # 「文字列の場合には setsockopt(2) にはその文字列と長さが渡されます。」の意味がわからん…。
    # そもそもRubyのコードはCに変換されるのか？
    # setsockopt 自体のソース https://docs.ruby-lang.org/en/2.4.0/BasicSocket.html#method-i-setsockopt
    #  v = RSTRING_PTR(val); あたりがポイントみたい。
    # pp mreq
    # ここ、出力確認すると空だな…。出力が間違っているのか、ここのプロミスキャス処理が働いていないのか
    #  % sudo ~/src/ruby-3.0.0/compiled/bin/ruby sample_run.rb                  (git)-[main]
    #   kure.setsockopt.v:
    # pp $$
    # sleep 10
    # SystemCall 監視
    #   -> setsockopt(5, SOL_PACKET, PACKET_ADD_MEMBERSHIP, {mr_ifindex=if_nametoindex("eth1"), mr_type=PACKET_MR_PROMISC, mr_alen=0, mr_address=}, 16) = 0
    # puts "====mreq"
    # \x  -> 16進数
    # pp mreq # \x04\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
    # char arg[16] = "3000100000000000"; <- Cで設定した時
    socket.setsockopt(SOL_PACKET, PACKET_ADD_MEMBERSHIP, mreq)
  end
end
