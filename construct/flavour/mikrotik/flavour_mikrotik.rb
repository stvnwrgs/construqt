require 'construct/flavour/flavour.rb'
require 'construct/flavour/mikrotik/flavour_mikrotik_schema.rb'
require 'construct/flavour/mikrotik/flavour_mikrotik_ipsec.rb'
require 'construct/flavour/mikrotik/flavour_mikrotik_bgp.rb'
require 'construct/flavour/mikrotik/flavour_mikrotik_result.rb'
require 'construct/flavour/mikrotik/flavour_mikrotik_interface.rb'


module Construct
module Flavour
module Mikrotik


  def self.name
    'mikrotik'
  end
  Flavour.add(self)    

  module Device
    def self.build_config(host, iface)
      default = {
        "l2mtu" => Schema.int.default(1590),
        "mtu" => Schema.int.default(1500),
        "name" => Schema.identifier.default("dummy"),
        "default-name" => Schema.identifier.required.key.noset
      }
      host.result.delegate.render_mikrotik_set_by_key(default, {
        "l2mtu" => iface.mtu,
        "mtu" => iface.mtu,
        "name" => iface.name,
        "default-name" => iface.default_name
      }, "interface")
    end
  end

  module Vrrp
    def self.build_config(host, iface)
      default = {
        "interface" => Schema.identifier.required,
        "name" => Schema.identifier.key.required,
        "priority" => Schema.int.required,
        "v3-protocol" => Schema.identifier.required,
        "vrid" => Schema.int.required
      }
      host.result.delegate.render_mikrotik(default, {
        "interface" => iface.interface.name,
        "name" => iface.name,
        "priority" => iface.interface.priority,
        "v3-protocol" => "ipv6",
        "vrid" => iface.vrid
      }, "interface", "vrrp")
    end
  end

  module Bond
    def self.scheduler_hack(host, iface)
      #binding.pry if iface.name=="sw12"
      return [] unless iface.interfaces.find{|iface| iface.clazz.simple_name == "Bond" }  

      system_script_schema = {
        "name" => Schema.identifier.key.required,
        "source" => Schema.source.required
      }
      host.result.delegate.render_mikrotik(system_script_schema, {
        "no_auto_disable" => true,
        "name" => "disable-#{iface.name}",
        "source" => <<SRC
/interface bonding disable [ find name=#{iface.name} ]
/system scheduler enable [ find name=enable-#{iface.name} ]
SRC
      }, "system", "script")

      or_condition = "(" + iface.interfaces.map{|iface| "name=#{iface.name}"}.join(" or ") + ")"
      host.result.delegate.render_mikrotik(system_script_schema, {
        "no_auto_disable" => true,
        "name" => "enable-#{iface.name}",
        "source" => <<SRC
:local run [ /interface bonding find running=yes and #{or_condition}]
:if ($run!="") do={ 
  /interface bonding enable [find name=sw12]
  /system schedule disable [ find name=enable-sw12 ] 
} 
SRC
      }, "system", "script")

      system_scheduler_script = {
        "name" => Schema.identifier.key.required,
        "on-event" => Schema.identifier.required,
        "start-time" => Schema.identifier.null,
        "interval" => Schema.interval.null,
        "disabled" => Schema.boolean.default(false)
      }
      host.result.delegate.render_mikrotik(system_scheduler_script, {
        "name" => "disable-#{iface.name}",
        "on-event" => "disable-#{iface.name}",
        "start-time" => "startup"
      }, "system", "scheduler")

      host.result.delegate.render_mikrotik(system_scheduler_script, {
        "name" => "enable-#{iface.name}",
        "on-event" => "enable-#{iface.name}",
        "interval" => "00:00:10",
        "disabled" => true
      }, "system", "scheduler")
    end
    def self.build_config(host, iface)
      default = {
        "mode" => Schema.string.default("active-backup"),
        "mtu" => Schema.int.required,
        "name" => Schema.identifier.required.key,
        "slaves" => Schema.identifiers.required,
      }
      host.result.delegate.render_mikrotik(default, {
        "mtu" => iface.mtu,
        "name" => iface.name,
        "mode" => iface.mode,
        "slaves" => iface.interfaces.map{|iface| iface.name}.join(',')
      }, "interface", "bonding")
      scheduler_hack(host, iface)
    end
  end

  module Vlan
    def self.build_config(host, iface)
      default = {
        "interface" => Schema.identifier.required,
        "mtu" => Schema.int.required,
        "name" => Schema.identifier.required.key,
        "vlan-id" => Schema.int.required,
      }
      host.result.delegate.render_mikrotik(default, {
        "interface" => iface.interface.name,
        "mtu" => iface.mtu,
        "name" => iface.name,
        "vlan-id" => iface.vlan_id
      }, "interface", "vlan")
    end
  end

  module Bridge
    def self.build_config(host, iface)
      default = {
        "auto-mac" => Schema.boolean.default(true),
        "mtu" => Schema.int.required,
        "priority" => Schema.int.default(57344),
        "name" => Schema.identifier.required.key
      }
      host.result.delegate.render_mikrotik(default, {
        "mtu" => iface.mtu,
        "name" => iface.name,
        "priority" => iface.priority
      }, "interface", "bridge")
      iface.interfaces.each do |port|
        host.result.delegate.render_mikrotik({
          "bridge" => Schema.identifier.required.key,
          "interface" => Schema.identifier.required.key
        }, {
          "interface" => port.name,
          "bridge" => iface.name,
        }, "interface", "bridge", "port")
      end
    end
  end

  module Host
    def self.header(host)
      host.result.delegate.render_mikrotik_set_direct({ "name"=> Schema.identifier.required.key }, 
                                                      { "name" => host.name }, "system", "identity")
      dns = host.dns_servers || [IPAddress.parse('2001:4860:4860::8844'),IPAddress.parse('2001:4860:4860::8888')]
      host.result.delegate.render_mikrotik_set_direct({"servers"=>Schema.addresses.required.key }, 
                                                      { "servers"=> dns }, "ip", "dns")

      host.result.add("set [ find name!=ssh && name!=www-ssl ] disabled=yes", nil, "ip", "service")
      host.result.add("set [ find ] address=#{host.id.first_ipv6.first_ipv6}", nil, "ip", "service")
      host.result.add("set [ find name!=admin ] comment=REMOVE", nil, "user")

      host.result.delegate.render_mikrotik({
        "name" => Schema.identifier.required.key,
        "enc-algorithms" => Schema.identifier.default("aes-256-cbc"),
        "lifetime" => Schema.interval.default("00:01:00"),
        "pfs-group"=> Schema.identifier.default("modp1536")
      }, {"name" => "s2b-proposal"}, "ip", "ipsec", "proposal")
      host.result.add("", "default=yes", "ip", "ipsec", "proposal")
      host.result.add("", "template=yes", "ip", "ipsec", "policy")
      host.result.add("", "name=default", "routing", "bgp", "instance")
      host.result.delegate.add_remove_pre_condition('comment~"CONSTRUCT\$"', "ip", "address")
      host.result.delegate.add_remove_pre_condition('comment~"CONSTRUCT\$"', "ip", "route")
      host.result.delegate.add_remove_pre_condition('comment~"CONSTRUCT\$"', "ipv6", "address")
      host.result.delegate.add_remove_pre_condition('comment~"CONSTRUCT\$"', "ipv6", "route")
      Users.users.each do |u|
        host.result.add(<<OUT, nil, "user")
{
   :local found [find name=#{u.name.inspect} ]
   :if ($found = "") do={
       add comment=#{u.full_name.inspect} name=#{u.name} password=#{Construct::Hosts::default_password} group=full
   } else={
     set $found comment=#{u.full_name.inspect}
   }
}
OUT
      end
      host.result.add("remove [find comment=REMOVE ]", nil, "user" )
      host.result.add("set [ find name=admin] disable=yes", nil, "user")
    end
    def self.build_config(host, unused)
      ret = ["# host"]
    end
  end
  module Ovpn
    def self.build_config(host, iface)
      throw "ovpn not impl"
    end
  end
  module Gre
    def self.set_interface_gre(host, cfg) 
      default = {
        "name"=>Schema.identifier.required.key,
        "local-address"=>Schema.address.required,
        "remote-address"=>Schema.address.required,
        "dscp"=>Schema.identifier.default("inherit"),
        "mtu"=>Schema.int.default(1476),
        "l2mtu"=>Scheme.int.default(65535)
      }
      host.result.delegate.render_mikrotik(default, cfg, "interface", "gre")
    end
    def self.set_interface_gre6(host, cfg) 
      default = {
        "name"=>Schema.identifier.required.key,
        "local-address"=>Schema.address.required,
        "remote-address"=>Schema.address.required,
        "mtu"=>Schema.int.default(1456),
        "l2mtu"=>Schema.int.default(65535)
      }
      host.result.delegate.render_mikrotik(default, cfg, "interface", "gre6")
    end
    def self.build_config(host, iface)
      #puts "iface.name=>#{iface.name}"
      #binding.pry
      #iname = Util.clean_if("gre6", "#{iface.name}")
      set_interface_gre6(host, "name"=> iface.name, 
                         "local-address"=>iface.local,
                         "remote-address"=>iface.remote)
      #Mikrotik.set_ipv6_address(host, "address"=>iface.address.first_ipv6.to_string, "interface" => iname)
    end
  end
  def self.set_ipv6_address(host, cfg)
    default = {
      "address"=>Schema.network.required,
      "interface"=>Schema.identifier.required,
      "comment" => Schema.string.required.key,
      "advertise"=>Schema.identifier.default("no")
    }
    cfg['comment'] = "#{cfg['interface']}-#{cfg['address']}"
    host.result.delegate.render_mikrotik(default, cfg, "ipv6", "address")
  end
  module Template
    def self.build_config(host, iface)
      throw "template not impl"
    end
  end
  def self.clazz(name)
    ret = {
      "opvn" => Ovpn,
      "gre" => Gre,
      "host" => Host,
      "device"=> Device,
      "vrrp" => Vrrp,
      "bridge" => Bridge,
      "bond" => Bond,
      "vlan" => Vlan,
      "result" => Result,
      "template" => Template
    }[name]
    throw "class not found #{name}" unless ret
    ret
  end
  def self.create_interface(name, cfg)
    cfg['name'] = name
    iface = Interface.new(cfg)
    iface
  end

  def self.create_bgp(cfg)
    Bgp.new(cfg)
  end
  def self.create_ipsec(cfg)
    Ipsec.new(cfg)
  end
end
end
end
