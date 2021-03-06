module Construqt
  module Flavour
    module Nixian
      module Services
          module Firewall
            class RequestDirection < Direction
              def initialize(to_from, family)
                super(to_from, family)
                self.interface_direction("-o")
              end

              def is_not_src_ip?
                to_from.rule.not_from?
              end

              def src_ip_list
                to_from.rule.from_list(family)
              end

              def is_not_dst_ip?
                to_from.rule.not_to?
              end

              def dst_ip_list
                to_from.rule.to_list(family)
              end

              def create_begin_middle_end(protocol)
                begin_middle_end = super(protocol)

                if to_from.rule.get_log
                  begin_middle_end.push_end("--nflog-prefix :#{to_from.rule.get_log}#{self.ifname.gsub(/[^a-zA-Z0-9]/,":")}")
                end

                if to_from.rule.respond_to?(:connection?) && to_from.rule.connection?
                  begin_middle_end.push_middle("-m conntrack --ctstate NEW,ESTABLISHED")
                end

                unless protocol.include?('icmp')
                  if (to_from.rule.get_dports && !to_from.rule.get_dports.empty?) ||
                      (to_from.rule.get_sports && !to_from.rule.get_sports.empty?)
                    begin_middle_end.push_middle("-m multiport")
                  end

                  if to_from.rule.get_dports && !to_from.rule.get_dports.empty?
                    begin_middle_end.push_middle("--dports #{Direction.prepare_ports(to_from.rule.get_dports)}")
                  end

                  if to_from.rule.get_sports && !to_from.rule.get_sports.empty?
                    begin_middle_end.push_middle("--sports #{Direction.prepare_ports(to_from.rule.get_sports)}")
                  end
                end

                if protocol.include?('icmp') && to_from.rule.icmp? && to_from.rule.get_type
                  state = {
                    Construqt::Firewalls::ICMP::Ping => {
                      Construqt::Addresses::IPV4 => "-m icmp --icmp-type 8/0",
                      Construqt::Addresses::IPV6 => "--icmpv6-type 128",
                    }
                  }[to_from.rule.get_type][family]
                  throw "state for #{to_from.rule.get_type} #{family}" unless state
                  begin_middle_end.push_middle(state)
                end

                begin_middle_end
              end
            end
          end
        end
      end
    end
  end
