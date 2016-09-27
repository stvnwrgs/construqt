module Construqt
  module Flavour
    class Ciscian
      module Dialect
        module Hp
          class Hp2510g

            def commit
            end

            def sort_section_keys(keys)
              keys.sort do |a, b|
                a = a.to_s
                b = b.to_s
                match_a = /^(.*[^\d])(\d+)$/.match(a) || [nil, a, 1]
                match_b = /^(.*[^\d])(\d+)$/.match(b) || [nil, b, 1]
                # puts match_a, match_b, a, b
                ret = 0
                ret = Construqt::Util.rate_higher('hostname', match_a[1], match_b[1]) if ret == 0
                ret = Construqt::Util.rate_higher('snmp', match_a[1], match_b[1]) if ret == 0
                ret = Construqt::Util.rate_higher('trunk', match_a[1], match_b[1]) if ret == 0
                ret = Construqt::Util.rate_higher('max-vlans', match_a[1], match_b[1]) if ret == 0
                ret = Construqt::Util.rate_higher('vlan', match_a[1], match_b[1]) if ret == 0
                ret = Construqt::Util.rate_higher('vlan', match_a[1], match_b[1]) if ret == 0
                ret = match_a[1] <=> match_b[1] if ret == 0
                ret = match_a[2].to_i <=> match_b[2].to_i if ret == 0
                ret
              end
            end

            def expand_vlan_device_name(device)
              expand_device_name(device, 'po' => 'Trk%s', 'ge' => '%s')
            end

            def expand_device_name(device, map = { 'po' => 'Trk%s', 'ge' => 'ethernet %s' })
              return device.delegate.dev_name if device.delegate.dev_name
              pattern = map[device.name[0..1]]
              throw "device not expandable #{device.name}" unless pattern
              pattern % device.name[2..-1]
            end

            def add_host(host)
              result = host.result
              result.add('hostname').add(result.host.name).quotes
              result.add('max-vlans').add(64)
              result.add("snmp-server community \"public\"")


              contact = "#{ENV['USER']}-#{`hostname`.strip}-#{`git  show --format=%h -q`.strip}-#{Time.now.to_i}"
              if host.region.network.contact
                contact = "#{contact} <#{host.region.network.contact}>"
              end
              result.add('snmp-server contact').add(contact).quotes

              if host.delegate.location
                result.add('snmp-server location').add(host.delegate.location).quotes
              end

              # enable ssh per default
              result.add('ip ssh')
              result.add('ip ssh filetransfer')

              # disable tftp per default
              result.add('no tftp client')
              result.add('no tftp server')

              # timezone defaults
              result.add('time timezone').add(60)
              result.add('time daylight-time-rule').add('Western-Europe')
              result.add('console inactivity-timer').add(10)

              result.host.interfaces.values.each do |iface|
                next unless iface.delegate.address
                iface.delegate.address.routes.each do |route|
                  result.add("ip route #{route.dst} #{route.dst.netmask} #{route.via}")
                end
              end

              write_sntp(host)

              result.add('spanning-tree') if host.delegate.spanning_tree

              if host.delegate.logging
                result.add('logging').add(host.delegate.logging)
              end
            end

            def write_sntp(host)
              if host.region.network.ntp.servers.first_ipv4
                host.result.add('sntp server ').add(host.region.network.ntp.servers.first_ipv4)
                host.result.add('timesync sntp')
                host.result.add('sntp unicast')
              end
            end

            def add_device(_device)
            end

            def add_bond(bond)
              result.add('trunk', TrunkVerb).add('{+ports}' => bond.interfaces.map { |i| i.delegate.number }, '{*channel}' => bond.delegate.number, '{=mode}' => 'LACP')
              result.add("spanning-tree #{expand_vlan_device_name(bond)} priority 4")
            end

            def add_vlan(vlan)
              result = vlan.host.result
              result.add("vlan #{vlan.delegate.vlan_id}", NestedSection) do |section|
                next unless vlan.delegate.description && !vlan.delegate.description.empty?
                throw 'vlan name too long, max 32 chars' if vlan.delegate.description.length > 32
                section.add('name').add(vlan.delegate.description).quotes
                section.add('jumbo')
                vlan.interfaces.each do |port|
                  range = nil
                  if port.template.is_tagged?(vlan.vlan_id)
                    range = section.add('tagged', Tagged)
                    range.add('{+ports}' => [expand_vlan_device_name(port)])
                  elsif port.template.is_untagged?(vlan.vlan_id)
                    range = section.add('tagged', Tagged)
                    range.add('{+uports}' => [expand_vlan_device_name(port)])
                  elsif port.template.is_nountagged?(vlan.vlan_id)
                    range = section.add('tagged', Tagged)
                    range.add('{-uports}' => [expand_vlan_device_name(port)])
                  end
                end

                if vlan.delegate.address
                  if vlan.delegate.address.first_ipv4
                    section.add('ip address').add(vlan.delegate.address.first_ipv4.to_s + ' ' + vlan.delegate.address.first_ipv4.netmask)
                  elsif vlan.delegate.address.dhcpv4?
                    section.add('ip address').add('dhcp-bootp')
                  end
                end

                section.add('ip igmp') if vlan.delegate.igmp
              end
            end

            def parse_line(line, lines, section, result)
              [TrunkVerb, Tagged
              ].find do |i|
                i.parse_line(line, lines, section, result)
              end
            end

            def clear_interface(line)
              line.to_s.split(/\s+/).map do |i|
                split = /^([^0-9]+)([0-9].*)$/.match(i)
                split ? split[1..-1] : i
              end.flatten.join(' ')
            end

            def is_virtual?(line)
              line.include?('vlan')
            end

            def block_end?(line)
              %w(end exit).include?(line.strip)
            end

            class Tagged < PatternBasedVerb
              def self.section
                'tagged'
              end

              def self.patterns
                ['tagged {+ports}', 'no tagged {-ports}', 'untagged {+uports}', 'no untagged {-uports}']
              end
            end

            class TrunkVerb < PatternBasedVerb
              def self.section
                'trunk'
              end

              def self.find_regex(variable)
                {
                  'mode' => '(Trunk|LACP)'
                }[variable]
              end

              def prefer_no_verbs?
                true
              end

              def self.patterns
                ['no trunk {-ports}', 'trunk {+ports} Trk{*channel} {=mode}']
              end
            end
          end

          #Construqt::Flavour::Ciscian.add_dialect(Hp2510g)
        end
      end
    end
  end
end