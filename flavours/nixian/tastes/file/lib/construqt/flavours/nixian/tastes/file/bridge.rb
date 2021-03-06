module Construqt
  module Flavour
    module Nixian
      module Tastes
        module File
          class Bridge
            def on_add(ud, taste, iface, me)
              # binding.pry if iface.name == "etcbind-2"
              fsrv = @context.find_instances_from_type(Construqt::Flavour::Nixian::Services::EtcNetworkNetworkUd::OncePerHost)
              fsrv.up("brctl addbr #{iface.name}")
              iface.interfaces.each do |brif|
                fsrv.up("brctl addif #{iface.name} #{brif.name}")
                fsrv.down("brctl delif #{iface.name} #{brif.name}")
              end
              fsrv.down("brctl delbr #{iface.name}")
            end
            def activate(ctx)
              @context = ctx
              self
            end
          end
          add(Entities::Bridge, Bridge)
        end
      end
    end
  end
end
