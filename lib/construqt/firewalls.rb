module Construqt
  module Firewalls

    @firewalls = {}
    module Actions
      NOTRACK = :NOTRACK
      SNAT = :SNAT
      ACCEPT = :ACCEPT
      DROP = :DROP
    end

    module ICMP
      PingRequest = :ping_request
    end

    class Firewall
      def initialize(name)
        @name = name
        @raw = Raw.new(self)
        @nat = Nat.new(self)
        @forward = Forward.new(self)
        @host = Host.new(self)
        @ipv4 = true
        @ipv6 = true
      end

      def ipv4?
        @ipv4
      end
      def only_ipv4
        @ipv4 = true
        @ipv6 = false
        self.clone
      end

      def ipv6?
        @ipv6
      end
      def only_ipv6
        @ipv4 = false
        @ipv6 = true
        self.clone
      end

      def name
        @name
      end

      class Raw
        attr_reader :firewall
        def initialize(firewall)
          @firewall = firewall
          @rules = []
        end

        class RawEntry
          include Util::Chainable
          chainable_attr :prerouting, true, false, lambda{|i| @output = false; input_only(true); output_only(false) }
          chainable_attr :input_only, true
          chainable_attr :output, true, false, lambda {|i| @prerouting = false; input_only(false); output_only(true) }
          chainable_attr :output_only, true
          chainable_attr :interface
          chainable_attr :from_my_net, true, false
          chainable_attr :to_my_net, true, false
          chainable_attr_value :from_net, nil
          chainable_attr_value :to, nil
          chainable_attr_value :to_net, nil
          chainable_attr_value :action, nil


          def initialize
            @from_is = nil
          end

          def from_is_inbound?
            @from_is == :inbound
          end
          def from_is_outbound?
            @from_is == :outbound
          end
          def from_is(direction)
            @from_is = direction
          end
        end

        def add
          entry = RawEntry.new
          @rules << entry
          entry
        end


        def rules
          @rules
        end
      end

      def get_raw
        @raw
      end

      def raw(&block)
        block.call(@raw)
      end

      class Nat
        attr_reader :firewall, :rules
        def initialize(firewall)
          @firewall = firewall
          @rules = []
        end

        class NatEntry
          include Util::Chainable
          chainable_attr :prerouting, true, false, lambda{|i| @postrouting = false; input_only(true); output_only(false) }
          chainable_attr :input_only
          chainable_attr :postrouting, true, false, lambda{|i| @prerouting = false; input_only(false); output_only(true) }
          chainable_attr :output_only
          chainable_attr :to_source
          chainable_attr :interface
          chainable_attr :from_my_net, true, false
          chainable_attr :to_my_net, true, false
          chainable_attr_value :from_net, nil
          chainable_attr_value :to_net, nil
          chainable_attr_value :action, nil

          def initialize
            @from_is = nil
          end

          def from_is_inbound?
            @from_is == :inbound
          end
          def from_is_outbound?
            @from_is == :outbound
          end
          def from_is(direction)
            @from_is = direction
          end
        end

        def add
          entry = NatEntry.new
          @rules << entry
          entry
        end
      end

      def get_nat
        @nat
      end

      def nat(&block)
        block.call(@nat)
      end

      class Mangle
        @rules = []
        class Tcpmss
        end

        def tcpmss
          @rules << Tcpmss.new
        end
      end

      def mangle(&block)
        block.call(@mangle)
      end

      class Forward
        attr_reader :firewall, :rules
        def initialize(firewall)
          @firewall = firewall
          @rules = []
        end

        class ForwardEntry
          include Util::Chainable
          chainable_attr :interface
          chainable_attr :connection
          chainable_attr :input_only, true, true
          chainable_attr :output_only, true, true
          chainable_attr :from_my_net, true, false
          chainable_attr :to_my_net, true, false
          chainable_attr :from_route, true, false
          chainable_attr :connection
          chainable_attr :link_local
          chainable_attr :icmp
          chainable_attr :esp
          chainable_attr :ah
          chainable_attr :tcp
          chainable_attr :udp
          chainable_attr :type, nil
          chainable_attr_value :log, nil
          chainable_attr_value :from_net, nil
          chainable_attr_value :from_net_addr, nil
          chainable_attr_value :to_net, nil
          chainable_attr_value :to_net_addr, nil
          chainable_attr_value :action, nil

          def initialize
            @from_is = nil
          end

          def from_is_inbound?
            @from_is == :inbound
          end
          def from_is_outbound?
            @from_is == :outbound
          end
          def from_is(direction)
            @from_is = direction
          end

          def port(port)
            @ports ||= []
            @ports << port
            self
          end

          def get_ports
            @ports ||= []
          end
        end

        def add
          entry = ForwardEntry.new
          #puts "ForwardEntry: #{@firewall.name} #{entry.input_only?} #{entry.output_only?}"
          @rules << entry
          entry
        end
      end

      def get_forward
        @forward
      end

      def forward(&block)
        block.call(@forward)
      end

      class Host
        attr_reader :firewall, :rules
        def initialize(firewall)
          @firewall = firewall
          @rules = []
        end

        class HostEntry < Forward::ForwardEntry
          #include Util::Chainable
          alias_method :from_me, :from_my_net
          alias_method :to_me, :to_my_net
        end

        def add
          entry = HostEntry.new
          #puts "ForwardEntry: #{@firewall.name} #{entry.input_only?} #{entry.output_only?}"
          @rules << entry
          entry
        end
      end

      def get_host
        @host
      end

      def host(&block)
        block.call(@host)
      end

      #    class Input
      #      class All
      #      end

      #      @rules = []
      #      def all(cfg)
      #        @rules << All.new(cfg)
      #      end

      #    end
    end

    def self.add(name, &block)
      throw "firewall with this name exists #{name}" if @firewalls[name]
      fw = @firewalls[name] = Firewall.new(name)
      block.call(fw)
      fw
    end

    def self.find(name)
      ret = @firewalls[name]
      throw "firewall with this name #{name} not found" unless @firewalls[name]
      ret
    end
  end
end
