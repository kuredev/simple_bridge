class SimpleBridge::RecvMessage
  def initialize(mesg)
    @mesg = mesg
  end

  # @return [String] ARP、HTTP、ICMP
  def protocol
    if @mesg.byteslice(12, 2).bytes.join == "86"
      "arp"
    elsif @mesg[23].bytes == [1]
      "icmp"
    elsif @mesg[37].bytes == [80]
      "http"
    else
      "unknown"
    end
  end
end
