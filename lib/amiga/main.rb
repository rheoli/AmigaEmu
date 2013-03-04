

module Amiga
  
  class Main
    def initialize
      @memory=Memory.new 
      @cpu=CPU.new :memory=>@memory
    end
    
    def memory
      @memory
    end
    
    def cpu
      @cpu
    end
    
    def load_rom(_rom_file)
      data=File.open(_rom_file, "rb").read
      base=0
      puts [:rom, :size, data.size, "%x" % data.size].inspect
      if data.size==0x80000
        base=0xf80000
        count=0
        data.each_byte do |b|
          @memory.set8(base+count, b)
          count+=1
        end
      elsif data.size==0x40000
        base=0xfc0000
        count=0
        data.each_byte do |b|
          @memory.write8(base+count, b)
          count+=1
        end
      else
        puts [:rom, :size, data.size, "%x" % data.size].inspect
      end
      @cpu.set_reg(:pc, base+2)
    end
    
    def start
      @running=true
      while @running
        @cpu.next_op
      end
    end
    
  end
end
