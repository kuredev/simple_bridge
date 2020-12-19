require_relative "lib/simple_bridge"

br = SimpleBridge::Bridge.new("eth0", "eth1")
br.run
