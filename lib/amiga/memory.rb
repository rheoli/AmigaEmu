module Amiga
  
  class MemoryException < Exception
  end
  
  class Memory
    def initialize
      @memory={}
    end
    
    def write8(_addr, _data)
      @memory[_addr]=_data
    end
    
    def read8(_addr)
      read_x(_addr, 1)
    end
    
    def read16(_addr)
      read_x(_addr, 2)
    end
    
    def read32(_addr)
      read_x(_addr, 4)
    end
    
    def read_x(_addr, _x)
      0.upto(_x-1) do |c|
        unless @memory.has_key?(_addr+c)
          raise MemoryException.new("Segfault (no R memory)")
        end
      end
      data=0
      0.upto(_x-1) do |c|
        data<<=8
        data+=@memory[_addr+c]
      end
      data
    end
    
    def write_x(_addr, _x, _data)
      0.upto(_x-1) do |c|
        unless @memory.has_key?(_addr+c)
          raise MemoryException.new("Segfault (no W memory)")
        end
      end
      (_x-1).downto(0) do |c|
        @memory[_addr+c]=_data&0xff
        _data>>=8
      end
    end
  
  end
  
end
