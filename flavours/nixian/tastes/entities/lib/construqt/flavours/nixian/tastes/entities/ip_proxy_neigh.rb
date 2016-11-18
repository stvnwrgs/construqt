

module Construqt
  module Flavour
    module Nixian
      module Tastes
        module Entities
          class IpProxyNeigh
            attr_reader :ip, :ifname
            def initialize(ip, ifname)
              @ip = ip
              @ifname = ifname
            end
          end
          add(IpProxyNeigh)
        end
      end
    end
  end
end
