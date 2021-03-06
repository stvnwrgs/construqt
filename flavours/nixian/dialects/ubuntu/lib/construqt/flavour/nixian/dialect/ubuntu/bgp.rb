module Construqt
  module Flavour
    module Nixian
      module Dialect
        module Ubuntu

          class Bgp
            attr_accessor :delegate, :other, :cfg
            attr_reader :host, :my, :as, :filter
            def initialize(cfg)
              self.other = cfg['other']
              self.cfg = cfg['cfg']
              @host = cfg['host']
              @my = cfg['my']
              @as = cfg['as']
              @filter = cfg['filter']
            end

            def self.header(host)
              return if host.bgps.empty?
              # binding.pry
              bird_v4 = self.header_bird(host, OpenStruct.new(:net_clazz => lambda {|o|
                (o.kind_of?(IPAddress::IPv4)||o.kind_of?(Construqt::Addresses::CqIpAddress)) && o.ipv4?
              },
              :filter => lambda {|ip| ip.ipv4? }))
              host.result.add(self, bird_v4, Construqt::Resources::Rights.root_0644(Construqt::Resources::Component::BGP), "etc", "bird", "bird.conf")
              bird_v6 = self.header_bird(host, OpenStruct.new(:net_clazz => lambda {|o|
                #(o.kind_of?(IPAddress::IPv6)||o.kind_of?(Construqt::Addresses::CqIpAddress)) && o.ipv6?
                o.ipv6?
              },
              :filter => lambda {|ip| ip.ipv6? }))
              host.result.add(self, bird_v6, Construqt::Resources::Rights.root_0644(Construqt::Resources::Component::BGP), "etc", "bird", "bird6.conf")
            end

            def self.header_bird(host, mode)
              #binding.pry
              ret = Construqt::Util.render(binding, "bgp_header.erb")
              Bgps.filters.each do |filter|
                ret = ret + "filter filter_#{filter.name} {\n"
                filter.list.each do |rule|
                  nets = rule['network']
                  if nets.kind_of?(String)
                    #binding.pry
                    nets = Construqt::Tags.find(nets, mode.net_clazz)
                    #            puts ">>>>>>>>>> #{nets.map{|i| i.class.name}}"
                    nets = IPAddress::summarize(nets)
                  else
                    nets = nets.ips
                  end

                  nets.each do |ip|
                    next unless mode.filter.call(ip)
                    ip_str = ip.to_string
                    if rule['addr_sub_prefix']
                      ip_str = "#{ip.to_string}{#{ip.prefix},#{ip.ipv4? ? 32 : 128}}"
                    elsif rule['prefix_length']
                      ip_str = "#{ip.to_string}{#{rule['prefix_length'].first},#{rule['prefix_length'].last}}"
                    end

                    #ret = ret + "  if net ~ [ #{ip_str} ] then { print \"#{rule['rule']}:\",net; #{rule['rule']}; }\n"
                    ret = ret + "  if net ~ [ #{ip_str} ] then { #{rule['rule']}; }\n"
                  end
                end

                ret = ret + "}\n\n"
              end

              ret
            end

            def build_bird_conf
              if self.my.address.first_ipv4 && self.other.my.address.first_ipv4
                cname = "#{Util.clean_bgp(self.my.host.name)}_#{Util.clean_bgp(self.other.host.name)}"
                write_start_stop(cname, self.my.address.first_ipv4, "gt4", "birdc")
                self.my.host.result.add(self, Construqt::Util.render(binding, "bgp_peer_v4.erb"),
                 Construqt::Resources::Rights.root_0644(Construqt::Resources::Component::BGP), "etc", "bird", "bird.conf")
              end
            end

            def write_start_stop(cname, my_ip, gt, cmd)
              local_if = host.interfaces.values.find { |iface| iface.address && iface.address.match_address(my_ip) }
              if local_if.clazz == "vrrp"
                writer = host.result.etc_network_vrrp(local_if.name)
                writer.add_master("/usr/sbin/#{cmd} enable #{cname}", 2000)
                writer.add_backup("/usr/sbin/#{cmd} disable #{cname}", -2000)
                local_if.services << Construqt::Services::BgpStartStop.new
                result.up_downer.add(local_if, Tastes::Entities::Bgp.new(cmd, cname))
              else
                iname = local_if.name
                if local_if.clazz == "gre"
                  iname = Util.clean_if(gt, iname)
                end
                #writer = host.result.etc_network_interfaces.get(local_if, iname)
                result.up_downer.add(local_if, Tastes::Entities::Bgp.new(cmd, cname))
              end
            end

            def build_bird6_conf
              if self.my.address.first_ipv6 && self.other.my.address.first_ipv6
                cname = "#{Util.clean_bgp(self.my.host.name)}_#{Util.clean_bgp(self.other.host.name)}"
                write_start_stop(cname, self.my.address.first_ipv6, "gt6", "birdc6")
                self.my.host.result.add(self, Construqt::Util.render(binding, "bgp_peer_v6.erb"),
                 Construqt::Resources::Rights.root_0644(Construqt::Resources::Component::BGP), "etc", "bird", "bird6.conf")
              end
            end

            def build_config(unused, unused1)
              # binding.pry
              build_bird_conf
              build_bird6_conf
            end
          end
        end
      end
    end
  end
end
