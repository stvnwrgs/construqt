module Construqt

  class Services
    def initialize
      @services = []
    end
    def get_services
      @services
    end
    def add(srv_s)
      unless srv_s.kind_of?(Array)
        srv_s = [srv_s]
      end
      @services += srv_s
    end

    def each(&block)
      @services.each(&block)
    end

    def map(&block)
      @services.map(&block)
    end

    def has_type_of?(kind)
      @services.find do |s|
        s.kind_of?(kind)
      end
    end

    def by_type_of(kind)
      @services.select do |s|
        s.kind_of?(kind)
      end
    end

    def include?(srv)
      @services.include?(srv)
    end

    def inspect
      "#<#{self.class.name}:#{object_id} services=[#{self.map{|i| i.class.name}.join(",")}]>"
    end

    def self.create(srvs)
      throw "can only create from array" unless srvs.kind_of?(Array)
      ret = Services.new
      ret.add(srvs)
      ret
    end


  end
end
