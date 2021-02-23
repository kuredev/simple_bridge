# simple_bridge

## How to use
Write as follows and execute with sudo

```ruby
require_relative "lib/simple_bridge"

br = SimpleBridge::Bridge.new("eth0", "eth1")
br.run
```

## What you can do
Forwarding packets between two network interfaces

## What you can not do
MAC address learning


## Referenced implementation

https://gist.github.com/k-sone/8036832    
https://gist.github.com/boxofrad/4511ba4357401a0ea7a04e4d394b9609#file-bind_socket-rb

# Related Links
https://kure.hatenablog.jp/entry/2020/12/20/004325
