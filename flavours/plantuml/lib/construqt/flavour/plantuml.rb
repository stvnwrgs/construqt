require 'rexml/document'
require 'rexml/element'
require 'rexml/cdata'

module Construqt
  module Flavour
    module Plantuml

      def self.name
        'plantuml'
      end

      Flavour.add_aspect(self)
      def self.simple(clazz)
        #     clazz
        clazz.name[clazz.name.rindex(':')+1..-1].gsub(/Delegate$/,'')
      end

      class Node
        attr_accessor :reference
        def initialize(reference)
          self.reference = reference
          throw "Node need a ident #{reference.class.name}" unless reference.ident
          #throw "Node need a clazz #{reference.class.name}" unless reference.clazz
          #      self.clazz = clazz
          @in_links = {}
          @out_links = {}
          @wire_in_links = {}
          @wire_out_links = {}
          @drawed = false
        end

        def in_links
          @in_links.values
        end

        def out_links
          @out_links.values
        end

        def wire_in_links
          @wire_in_links.values
        end

        def wire_out_links
          @wire_out_links.values
        end

        def ident
          reference.ident
        end

        def drawed=(a)
          @drawed = a
        end

        def drawed!
          prev = @drawed
          @drawed = true
          prev
        end

        def drawed?
          @drawed
        end

        def in_links=(node)
          @in_links[node.object_id] = node
        end

        def wire_in_links=(node)
          @wire_in_links[node.object_id] = node
        end

        def in_links?(node)
          @in_links[node.object_id]
        end

        def wire_in_links?(node)
          @in_links[node.object_id]
        end

        def connect(node)
          throw "node not set" unless node
          unless self.in_links?(node)
            @out_links[node.object_id] = node
            node.in_links = self
          end
        end

        def wire_connect(node)
          throw "node not set" unless node
          unless self.wire_in_links?(node)
            @wire_out_links[node.object_id] = node
            node.wire_in_links = self
          end
        end
      end

      @tree = {}
      @single_wire = {}

      def self.connect(node, out, path)
        return if node.drawed!
        #    Construqt.logger.debug("planuml.draw:#{node.reference.name} #{node.ident} ")
        node.out_links.each do |n|
          #      Construqt.logger.debug("planuml.draw:Out:#{node.reference.name} #{node.ident}:#{n.ident}")
          unless simple(node.reference.class) == "Host"
            out << "#{node.ident} .. #{n.ident}"
          end

          connect(n, out, path + [n.reference.name])
        end
        node.wire_out_links.each do |n|
          key = [node.ident,n.ident].sort.join('..')
          unless @single_wire[key]
            @single_wire[key] = true
            out << "#{node.ident} .. #{n.ident}"
          end
        end
      end

      def self.ident(path, content)
        ident = (0...path.length-1).to_a.map{ " " }.join('')
        content.lines.map{|i| ident+i }.join('')
      end

      def self.draw(node, out, path, flat, parent = nil)
        n_kind = simple(node.reference.class)
        if n_kind == "Host"
          # root calls but we have in_links so this is part of a
          # mother child connection
          return false if parent.nil? and !node.in_links.empty?
          # if my in_links contains my mother i'm ready to paint
          return false if !node.in_links.empty? and !node.in_links.include?(parent)
          return false if node.drawed! #ugly
          out << ident(path, "package \"#{node.ident}(#{node.reference.flavour.name})\" <<Node>> #DDDDDD {")
        else
          return false if node.drawed! #ugly
          out << ident(path, <<UML)
object #{node.ident} <<#{n_kind}>> {
          #{render_object_address(node.reference)}
}
UML
        end
        #binding.pry if node.ident == 'Host_scott'

        last = nil
        !flat && n_kind != 'Device' && node.out_links.each do |n|
          #binding.pry if n.reference.name == "ad-de"
          last = layout_helper(out, last, node,
                   draw(n, out, path + [n.reference.name], flat, node)
                 )
        end

        if n_kind == "Host"
          out << ident(path, "}")
        end
        true
      end

      def self.render_object_address(iface)
        tags = []
        out = []
        out << "name = \"#{iface.name}\""

        if iface.respond_to?(:mtu) && iface.mtu
          out << "mtu = \"#{iface.mtu}\""
        end
        if iface.kind_of? Construqt::Ipsecs::Ipsec
          out << "password = #{iface.password}"
          out << "transport_family = #{iface.transport_family}"
          out << "mtu_v4 = #{iface.mtu_v4}"
          out << "mtu_v6 = #{iface.mtu_v6}"
          out << "keyexchange = #{iface.keyexchange}"
        end
        binding.pry if name == 'ipsec'
        address = iface.address
        if iface.kind_of? Construqt::Flavour::IpsecVpnDelegate
          out << "auth_method = #{iface.auth_method}"
          out << "leftpsk = #{iface.leftpsk}"
          if iface.leftcert
            out << "leftcert = #{iface.leftcert.name}"
          end
          out << "ipv6_proxy = #{iface.ipv6_proxy}"
          address = iface.right_address
          ipsec_users.each do |user|
            out << "#{user.name} = #{user.psk}"
          end
        end
        if iface.respond_to?(:ssid) && iface.ssid
          out << "ssid = \"#{iface.ssid}\""
          out << "psk = \"#{iface.psk}\""
        end
        out << "desc = \"#{iface.description}\"" if iface.description
        if address
          [address.v4s, address.v6s].each do |ips|
            next unless ips.first
            prefix = ips.first.ipv4? ? "ipv4" : "ipv6"
            ips.each_with_index do |ip, idx|
              tags += Construqt::Tags.from(ip)||[]
              out << "#{prefix}(#{idx}) = #{ip.to_string}"
            end
          end

          if address.dhcpv4?
            out << "dhcpv4 = client"
          end

          if address.dhcpv6?
            out << "dhcpv6 = client"
          end

          address.routes.each_with_index do |route, idx|
            out << "route(#{idx}) = \"#{route.dst.to_string} via #{route.via.to_s}\""
          end
        end

        iface.delegate && iface.delegate.firewalls && iface.delegate.firewalls.each_with_index do |fw, idx|
          out << "fw(#{idx}) = \"#{fw.name}\""
        end

        iface.tags && (iface.tags+tags).sort.uniq.each_with_index do |tag, idx|
          out << "tag(#{idx}) = \"#{tag}\""
        end

        out.join("\n")
      end

      def self.clean_name(name)
        #name = name.gsub(/\s+/, '_')
        name.gsub(/[^0-9a-zA-Z_]/, '_')
      end

      def self.add_node_factory(type, host, *args)
        factory = {
          "BondDelegate.build_config" => lambda do |type, host, *args|
            args.first
          end,
          "BridgeDelegate.build_config" => lambda do |type, host, *args|
            args.first
          end,
          "DeviceDelegate.build_config" => lambda do |type, host, *args|
            #Construqt.logger.debug("DeviceDelegate.build_config:#{host.class.name} #{args.map{|i| i.name}}")
            args.first
          end,
          "HostDelegate.build_config" => lambda do |type, host, *args|
            #Construqt.logger.debug("Planuml:HostDelegate.build_config:#{host.name}")
            #binding.pry
            args.first
          end,
          "InterfaceDelegate.build_config" => lambda do |type, host, *args|
            nil
          end,
          "OpvnDelegate.build_config" => lambda do |type, host, *args|
            args.first
          end,
          "VlanDelegate.build_config" => lambda do |type, host, *args|
            args.first
          end,
          "WlanDelegate.build_config" => lambda do |type, host, *args|
            args.first
          end,
          "IpsecDelegate.build_config" => lambda do |type, host, *args|
            args.first.cfg
          end,
          "IpsecVpnDelegate.build_config" => lambda do |type, host, *args|
            args.first
          end,
          "VrrpDelegate.build_config" => lambda do |type, host, *args|
            args.first
          end,
          "GreDelegate.build_config" => lambda do |type, host, *args|
            args.first
          end,
          "BgpDelegate.build_config" => lambda do |type, host, *args|
            args.first.cfg
          end

        }

        method = factory[type]
        if method
          obj = method.call(type, host, *args)
          if obj
            ident = obj.ident
            throw "A object needs a ident #{obj.class.name}" unless ident
            @tree[ident] ||= Node.new(obj)
          end
        else
          Construqt.logger.debug "Planuml:add_node_factory type not found #{type}"
        end
      end

      def self.build_tree
        #binding.pry
        @tree.each do |ident, node|
          #binding.pry
          #Construqt.logger.debug "Planuml:build_tree=#{node.reference.class.name}=#{simple(node.reference.class)}"
          {
            "Vrrp" => lambda do |node|
              node.reference.delegate.interfaces.each do |i|
                node.connect @tree[i.ident]
              end
              node.reference.cable.connections.each do |c|
                node.wire_connect @tree[c.iface.ident]
              end
            end,
            "Vlan" => lambda do |node|
              node.reference.interfaces.each do |vlan_iface|
                node.connect @tree[vlan_iface.ident]
              end
              node.reference.cable.connections.each do |c|
                node.wire_connect @tree[c.iface.ident]
              end
            end,
            "Bond" => lambda do |node|
              node.reference.delegate.interfaces.each do |i|
                #Construqt.logger.debug(">>>>>>>>>> BOND -> #{simple(i.clazz)} #{i.name}")
                node.connect @tree[i.ident]
              end
              node.reference.cable.connections.each do |c|
                node.wire_connect @tree[c.iface.ident]
              end
            end,
            "Bridge" => lambda do |node|
              node.reference.delegate.interfaces.each do |i|
                #binding.pry
                node.connect @tree[i.ident]
              end
              node.reference.cable.connections.each do |c|
                #binding.pry
                node.wire_connect @tree[c.iface.ident]
              end
            end,
            "Wlan" => lambda do |node|
              node.reference.cable.connections.each do |c|
                node.wire_connect @tree[c.iface.ident]
              end
            end,
            "Device" => lambda do |node|
              node.reference.cable.connections.each do |c|
                #binding.pry
                node.wire_connect @tree[c.iface.ident]
              end
            end,
            "Template" => lambda do |node|
              #                iface.interface.delegate.vlans.each do |i|
              #                  iface.connect tree[simple(i.clazz)][i.name]
              #                end
            end,
            "Gre" => lambda do |node|
              #          binding.pry
              interface = node.reference.delegate.remote.interface
              node.connect @tree[interface.ident]
            end,
            "Opvn" => lambda do |node|
            end,
            "IpsecVpn" => lambda do |node|
              interface = node.reference.delegate.left_interface
              node.connect @tree[interface.ident]
            end,
            "Ipsec" => lambda do |node|
              [node.reference.lefts.first, node.reference.rights.first].each do |iface|
                binding.pry unless @tree[iface.interface.ident]
                node.connect @tree[iface.interface.ident]
              end
            end,
            "Bgp" => lambda do |node|
              #binding.pry
              [node.reference.lefts.first, node.reference.rights.first].each do |iface|
                node.connect @tree[iface.my.ident]
              end
            end,
            "Host" => lambda do |node|
              if node.reference.mother
                @tree[node.reference.mother.ident].connect node
              end
              node.reference.interfaces.values.each do |iface|
                next if simple(iface.class) == "Vrrp"
                Construqt.logger.debug "Planuml:Host:#{iface.name}:#{iface.ident}:#{simple(iface.class)}"
                node.connect @tree[iface.ident]
              end
            end

          }[simple(node.reference.class)].call(node)
        end
      end

      def self.layout_helper(out, last, node, drawed)
        return unless drawed
#        out << "#{last.ident} -down-> #{node.ident}" if last
        node
      end

      def self.patch_connection_highlight(fname)
        xml = REXML::Document.new(IO.read(fname))
        js = REXML::Element.new "script"
        js.text = REXML::CData.new(<<JS)
var paths = document.getElementsByTagName("path");
for (var i = 0; i < paths.length; ++i) {
  paths[i].style["stroke-width"] = "4px";
  paths[i].style["stroke-dasharray"] = "initial";
}
document.addEventListener("click", function(e) {
  var target = e.target
  console.log(target+":"+target.style["stroke-width"]);
  if (target.tagName != "path") {
    return;
  }
  if (parseInt(target.style["stroke-width"])==8) {
    return;
  }
  var old_width = target.style["stroke-width"];
  target.style["stroke-width"]="8px";
  setTimeout(function() {
    target.style["stroke-width"]=old_width;
  }, 1000)
});
JS
        xml.root.elements.add(js)
        File.open(fname, 'w') { |o| xml.write( o ) }
      end

      def self.call(type, *args)
        add_node_factory(type, *args)
        factory = {
          "completed" => lambda do |type, *args|
            build_tree
            out = []
            last = nil
            @tree.values.each do |node|
              #           next unless node.in_links.empty?
              last = layout_helper(out, last, node,
                                   draw(node, out, [node.reference.name],
                                        ['Vrrp', 'Ipsec', 'Bgp'].include?(simple(node.reference.class))))
            end

            @tree.values.each { |n| n.drawed = false }
            @tree.values.each do |node|
              #           next unless node.in_links.empty?
              connect(node, out, [node.reference.name])
            end

            File.open("cfgs/world.puml", 'w') do |file|
              file.puts(<<UML)
@startuml
skinparam object {
  ArrowColor<<Gre>> MediumOrchid
  BackgroundColor<<Gre>> MediumOrchid
  ArrowColor<<Bgp>> MediumSeaGreen
  BackgroundColor<<Bgp>> MediumSeaGreen
  ArrowColor<<Ipsec>> LightSkyBlue
  BackgroundColor<<Ipsec>> LightSkyBlue
  ArrowColor<<Vrrp>> OrangeRed
  BackgroundColor<<Vrrp>> OrangeRed
  ArrowColor<<Device>> YellowGreen
  BackgroundColor<<Device>> YellowGreen
  ArrowColor<<Bond>> Orange
  BackgroundColor<<Bond>> Orange
  ArrowColor<<Vlan>> Yellow
  BackgroundColor<<Vlan>> Yellow
  ArrowColor<<Wlan>> Red
  BackgroundColor<<Wlan>> Red
  ArrowColor<<Bridge>> Pink
  BackgroundColor<<Bridge>> Pink
}
skinparam stereotypeBackgroundColor<<Gre>> MediumOrchid
skinparam stereotypeBackgroundColor<<Bgp>> MediumSeaGreen
skinparam stereotypeBackgroundColor<<Ipsec>> LightSkyBlue
skinparam stereotypeBackgroundColor<<Vrrp>> OrangeRed
skinparam stereotypeBackgroundColor<<Device>> YellowGreen
skinparam stereotypeBackgroundColor<<Bond>> Orange
skinparam stereotypeBackgroundColor<<Vlan>> Yellow
skinparam stereotypeBackgroundColor<<Wlan>> Red
skinparam stereotypeBackgroundColor<<Bridge>> Pink
UML
              file.write(out.join("\n") + "\n")
              file.puts("@enduml")
            end

            if File.exists?("/cygdrive/c/Program Files/cygwin/bin/dot.exe")
              dot = "C:\\Program Files\\cygwin\\bin\\dot.exe"
            elsif File.exists?("/usr/bin/dot")
              dot = "/usr/bin/dot"
            else
              dot = "$(which dot)"
            end

            if  File.exists?("#{ENV['HOMEPATH']}/Downloads/plantuml.jar")
              plantuml_jar = "#{ENV['HOMEPATH']}/Downloads/plantuml.jar"
            else
              plantuml_jar = "$HOME/Downloads/plantuml.jar"
            end

            system("java -jar \"#{plantuml_jar}\" -Djava.awt.headless=true -graphvizdot \"#{dot}\" -tsvg cfgs/world.puml")
            patch_connection_highlight("cfgs/world.svg")
          end

        }
        Construqt.logger.debug "Planuml:#{type}"
        action = factory[type]
        if action
          action.call(type, *args)
        end
      end
    end
  end
end
