require_relative "lib/simple_bridge"

br = SimpleBridge::Bridge.new("eth1", "eth2")
br.run
