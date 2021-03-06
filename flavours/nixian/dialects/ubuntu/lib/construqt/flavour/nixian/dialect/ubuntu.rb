
require 'construqt/flavour/nixian.rb'

require 'construqt/flavours/nixian/tastes/entities.rb'
require 'construqt/flavours/nixian/tastes/systemd.rb'
#require 'construqt/flavours/nixian/tastes/flat.rb'
require 'construqt/flavours/nixian/tastes/debian.rb'
require 'construqt/flavours/nixian/tastes/file.rb'

require_relative 'ubuntu/dns.rb'
# require_relative 'ubuntu/ipsec/racoon.rb'
# require_relative 'ubuntu/ipsec/strongswan.rb'
require_relative 'ubuntu/bgp.rb'
# require_relative 'ubuntu/ipsec.rb'
require_relative 'ubuntu/opvn.rb'
require_relative 'ubuntu/vrrp.rb'
#require_relative 'ubuntu/firewall.rb'
require_relative 'ubuntu/container.rb'
# require_relative 'ubuntu/result/up_downer.rb'
#require_relative 'ubuntu/result.rb'

# require_relative 'ubuntu/services/conntrack_d.rb'
# require_relative 'ubuntu/services/dns_masq.rb'
# require_relative 'ubuntu/services/dhcp_client.rb'
# require_relative 'ubuntu/services/dhcp_v4_relay.rb'
# require_relative 'ubuntu/services/dhcp_v6_relay.rb'
# require_relative 'ubuntu/services/null.rb'
# require_relative 'ubuntu/services/radvd.rb'
# require_relative 'ubuntu/services/route_service.rb'
# require_relative 'ubuntu/services/vagrant.rb'
# require_relative 'ubuntu/services/docker.rb'
require_relative 'ubuntu/services/vagrant_impl.rb'
require_relative 'ubuntu/services/deployer_sh.rb'
require_relative 'ubuntu/services/packager_service.rb'
#require_relative 'ubuntu/services/result_factory.rb'

require_relative 'ubuntu/bond.rb'
require_relative 'ubuntu/bridge.rb'
require_relative 'ubuntu/device.rb'
require_relative 'ubuntu/gre.rb'
require_relative 'ubuntu/host.rb'
require_relative 'ubuntu/ipsecvpn.rb'
require_relative 'ubuntu/template.rb'
require_relative 'ubuntu/vlan.rb'
require_relative 'ubuntu/wlan.rb'
require_relative 'ubuntu/systemd.rb'
require_relative 'ubuntu/tunnel.rb'

module Construqt
  module Flavour
    module Nixian
      module Dialect
        module Ubuntu
          DIRECTORY = File.dirname(__FILE__)

          class Factory
            def name
              "ubuntu"
            end
            def produce(parent, cfg)
              Dialect.new(parent, cfg)
            end
          end

          class Dialect
            attr_reader :services_factory
            def initialize(factory, cfg)
              @factory = factory
              @cfg = cfg
              @services_factory = factory.services_factory.shadow()
              #@services_factory.add(Services::ResultFactory.new(@services_factory))
              @services_factory.add(Services::VagrantFactory.new)
            end

            def name
              'ubuntu'
            end

            def add_host_services(srvs)
              @services_factory.merge(srvs, [
                Construqt::Flavour::Nixian::Dialect::Ubuntu::Services::PackagerService.create,
                Construqt::Flavour::Nixian::Services::Result::Service.new,
                Construqt::Flavour::Nixian::Services::UpDowner::Service.new
                  .taste(Tastes::Systemd::Factory.new)
                  .taste(Tastes::Debian::Factory.new)
                  .taste(Tastes::File::Factory.new),
                Construqt::Flavour::Nixian::Services::SysCtlConf::Service.new,
                Construqt::Flavour::Nixian::Services::Invocation::Service.new,
                Construqt::Flavour::Nixian::Services::Lxc::Service.new,
                Construqt::Flavour::Nixian::Services::Docker::Service.new,
                Construqt::Flavour::Nixian::Services::Vagrant::Service.new,
                Construqt::Flavour::Nixian::Services::Ssh::Service.new,
                Construqt::Flavour::Nixian::Services::EtcSystemdNetdev::Service.new,
                Construqt::Flavour::Nixian::Services::EtcSystemdNetwork::Service.new,
                Construqt::Flavour::Nixian::Services::EtcSystemdService::Service.new,
                Construqt::Flavour::Nixian::Services::EtcNetworkInterfaces::Service.new,
                Construqt::Flavour::Nixian::Services::EtcNetworkNetworkUd::Service.new,
                Construqt::Flavour::Nixian::Services::EtcNetworkApplicationUd::Service.new,
                Construqt::Flavour::Nixian::Services::DeployerSh::Service.new,
                Construqt::Flavour::Nixian::Services::RejectRoutes::Service.new,
                Construqt::Flavour::Nixian::Services::Tunnel::Service.new,
                Construqt::Flavour::Nixian::Services::IpsecStrongSwan::Service.new
              ])
            end

            def add_interface_services(srvs)
              @services_factory.merge(srvs, [
                Construqt::Flavour::Nixian::Services::IpTables::Service.new,
                Construqt::Flavour::Nixian::Services::IpProxyNeigh::Service.new(),
                Construqt::Flavour::Nixian::Services::DnsMasq::Service.new(),
                Construqt::Flavour::Nixian::Services::DhcpClient::Service.new()
              ])
            end

            # def ipsec
            #   Ipsec::StrongSwan
            # end

            def bgp
              Bgp
            end

            def clazzes
              {
                "opvn" => Opvn,
                "gre" => Gre,
                "host" => Host,
                "device"=> Device,
                "vrrp" => Vrrp,
                "bridge" => Bridge,
                "bond" => Bond,
                "wlan" => Wlan,
                "vlan" => Vlan,
                "ipsecvpn" => IpsecVpn,
                "tunnel" => Tunnel,
                #"result" => Result,
                #"ipsec" => Ipsec,
                #"bgp" => Bgp,
                "template" => Template
              }
            end

            def clazz(name)
              ret = self.clazzes[name]
              throw "class not found #{name}" unless ret
              ret
            end

            def create_host(name, cfg)
              cfg['name'] = name
              cfg['result'] = nil
              cfg['dialect'] = self
              host = Host.new(cfg)
              #host.result = Result.new(host, up_downer)
              # host.flavour.services.each do |srv|
              #   up_downer.request_tastes_from(srv)
              # end
              host
            end

            def create_interface(name, cfg)
              cfg['name'] = name
              clazz(cfg['clazz']).new(cfg)
            end

            def create_bgp(cfg)
              Bgp.new(cfg)
            end

            # def vagrant_factory(host, ohost)
            #   Services::VagrantFile.new(host, ohost)
            # end

            def create_ipsec(cfg)
              # Ipsec::StrongSwan.new(cfg)
              connection = Construqt::Flavour::Nixian::Services::IpsecStrongSwan::Connection.new(cfg)
              # cfg['hosts'].each do |host|
              #   host.add_
              #   binding.pry
              #   #ipsec = @services_factory.find_instances_from_type(Construqt::Flavour::Nixian::Services::IpsecStrongSwan::OncePerHost)
              #   #ipsec.add_connection()
              # end
            end
          end
        end
      end
    end
  end
end
