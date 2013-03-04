require 'pp'
require 'yaml'

module Amiga
  
  class CPU
    def initialize(_hash)
      @memory=_hash[:memory] if _hash.has_key?(:memory)
      reset
    end
    
    def reset
      @regs={ :pc=>0, :sp=>0, :ccr=>0, :a=>[0]*7, :d=>[0]*7 }
      @flags={ :x=>false, :n=>false, :z=>false, :v=>false, :c=>false }
    end
    
    def set_reg(_reg, _data)
      @regs[_reg]=_data
    end
    
    def next_op
      op=read_mem_of_pc(:word)
      #p "%016b" % op
      bincode=('%016b' % op)
      cmd=M68K[bincode]
      if cmd.nil?
        p bincode
        exit 1
      end  
      send("cmd_#{cmd[0]}", cmd[1])
      #p INSTR_DEFS
      
      #p @regs
      #p @flags
    end
    
    def cmd_jmp(_args)
      puts [:jmp, _args].inspect
      addr=read_mem_of_pc(_args[0][0])
      @regs[:pc]=addr
    end
    
    def cmd_lea(_args)
      puts [:lea, _args].inspect
      reg=_args[0][1]
      size=:long
      size=:word if _args[1][0]==:_d16PC_
      addr=get_src(size, :data, 0)
      if _args[1][0]==:_d16PC_
        max=0x10000
        if addr&(max>>1)
          addr=(max-addr)*-1
        end
        addr+=(@regs[:pc]-2)
      end
      p "%x" % addr
      @regs[:a][reg]=addr
    end
    
    def cmd_moveq(_args)
      #puts [:moveq, _args].inspect
      reg=_args[0][1].to_i(2)
      data=_args[1][1].to_i(2)
      if (data&0x80)
        data-=0x80
        data*=-1
      end
      #puts [:moveq, data, "d: #{reg}"].inspect
      @regs[:d][reg]=data
      @flags[:n]=true if data<0
      @flags[:z]=true if data==0
      @flags[:v]=false
      @flags[:c]=false
    end
    
    def cmd_add(_args)
      puts [:add, _args].inspect
      exit 1
      sreg=_args[0][1].to_i(2)
      set_dst(??, _args[2][1][0], _args[2][1][1])
      if dtyp==:_An_p
        p "%x" % @regs[:a][dreg]
        @regs[:a][dreg]-=1
        p dval=@memory.read32(@regs[:a][dreg])
      end
      p dtyp
      exit 0
    end
    
    def get_src(_size, _type, _id)
      data=nil
      if _type==:data
        data=read_mem_of_pc(_size)
      end
      if _type==:An
        data=@regs[:a][_id]
      end
      if _type==:Dn
        data=@regs[:d][_id]
      end
      if _type==:_An_ or _type==:_An_p or _type==:m_An_
        @regs[:a][_id]-=1 if _type==:m_An_
        data=read_mem(_size, @regs[:a][_id])
        @regs[:a][_id]+=1 if _type==:_An_p
      end
      if data.nil?
        p _type
      end
  	  #m=":_d16An_" if mode==5
  	  #m=":_d8AnXn_" if mode==6
      data
    end
    
    def set_dst(_size, _type, _id, _data)
      if _type==:An
        @regs[:a][_id]=_data
      end
      if _type==:Dn
        @regs[:d][_id]=_data
      end
      if _type==:_An_ or _type==:_An_p or _type==:m_An_
        @regs[:a][_id]-=1 if _type==:m_An_
        data=write_mem(_size, @regs[:a][_id], _data)
        @regs[:a][_id]+=1 if _type==:_An_p
      end
    end
    
    #-[:subq, [[1, 1], [:long], [:Dn, 0]]]
    #-TODO: Check for flags, size of sub
    def cmd_subq(_args)
      #puts [:subq, _args].inspect
      data=get_src(_args[1][0], _args[2][0], _args[2][1])
      data-=_args[0][0]
      set_dst(_args[1][0], _args[2][0], _args[2][1], data)
      @flags[:n]=true if data<0
      @flags[:z]=true if data==0
      @flags[:v]=false
      @flags[:c]=false
    end
    
    #-Check Condition
    #-M68K Referenz Page 90
    #-TODO: Check the true and false conditions
    def check_cond(_cond)
      return true if _cond==:t
      return false if _cond==:f
      return (!@flags[:c] and !@flags[:z]) if _cond==:hi
      return (@flags[:c] or @flags[:z]) if _cond==:ls
      return !@flags[:c] if _cond==:cc
      return @flags[:c] if _cond==:cs
      return !@flags[:z] if _cond==:ne
      return @flags[:z] if _cond==:eq
      return !@flags[:v] if _cond==:vc
      return @flags[:v] if _cond==:vs
      return !@flags[:n] if _cond==:pl
      return @flags[:n] if _cond==:mi
      if _cond==:ge
        return (@flags[:n] and @flags[:v] or !@flags[:n] and !@flags[:v])
      end
      if _cond==:lt
        return (@flags[:n] and !@flags[:v] or !@flags[:n] and @flags[:v])
      end
      if _cond==:gt
        return (@flags[:n] and @flags[:v] and !@flags[:z] or !@flags[:n] and !@flags[:v] and !@flags[:z])
      end
      if _cond==:le
        return (@flags[:z] or @flags[:n] and !@flags[:v] or !@flags[:n] and @flags[:v])
      end
      false
    end
    
    #-[:bcc, [[:gt], [252, 252]]]
    def cmd_bcc(_args)
      #puts [:bcc, _args].inspect
      cond=check_cond(_args[0][0])
      if cond
        data=_args[1][0]
        #-negative data?
        data=(0x100-data)*(-1) if data&0x80
        @regs[:pc]+=data
      end
    end
    
    # [:move, [[:long], [:Dn, 0], [:data, 0]]]
    def cmd_move(_args)
      #puts [:move, _args].inspect
      data=get_src(_args[0][0], _args[2][0], _args[2][1])
      #p '%x' % data
      set_dst(_args[0][0], _args[1][0], _args[1][1], data)
      @flags[:n]=true if data<0
      @flags[:z]=true if data==0
      @flags[:v]=false
      @flags[:c]=false
    end
    
    def read_mem_of_pc(_size)
      read_mem(_size, :pc)
    end
    
    def read_mem(_size, _addr)
      addr=_addr
      addr=@regs[:pc] if _addr==:pc
      len=0
      len=1 if _size==:byte
      len=2 if _size==:word or _size==:_xxx_W
      len=4 if _size==:long or _size==:_xxx_L
      data=@memory.read_x(addr, len)
      @regs[:pc]+=len if _addr==:pc
      data
    end
    
    def write_mem(_size, _addr, _data)
      addr=_addr
      addr=@regs[:pc] if _addr==:pc
      len=0
      len=1 if _size==:byte
      len=2 if _size==:word or _size==:_xxx_W
      len=4 if _size==:long or _size==:_xxx_L
      data=@memory.write_x(addr, len, _data)
      @regs[:pc]+=len if _addr==:pc
    end
    
    M68K={}
    
    def self.set_m68k(_name, *_opts)
      @@yaml||=nil
      if @@yaml.nil?
        @@yaml=YAML.load(File.open("data/m68k.yaml"))
        #p @@yaml
      end
      a=[]
      if _opts.class==Array
        _opts.each do |opt|
          if opt.class==String
            if a.size==0
              a<<[opt]
            else
              aa=[]
              a.each do |x|
                x[0]+=opt
                aa<<x
              end
              a=aa
            end
          elsif opt.class==Symbol and @@yaml.has_key?(opt)
            aa=[]
            a.each do |x|
              @@yaml[opt].each do |t,v|
                aa<<([x[0]+t]+x[1..-1]+[v])
              end
            end
            a=aa
            #a=a.collect { |x| p "1"; p x; s=[]; @@yaml[opt].each { |t,v| s<<[x[0]+t] }; s }
          end
        end
      end
      #pp a if _name==:bcc
      a.each do |m|
        if m[0].size==16
          M68K[m[0]]=[_name, m[1..-1]]
        end
      end
      #pp M68K
      #exit 1
    end
    
    set_m68k(:move,  "00", :Size2_0, :XnAm, :AmXn)
    set_m68k(:movea, "00", :Size2_0, :Xn, "001", :AmXn)
    set_m68k(:moveq, "0111", :Xn, "0", :Data8)
    set_m68k(:movem, "010010001", :Size1, :AmXn)
    set_m68k(:movem, "010011001", :Size1, :AmXn)
    set_m68k(:lea,   "0100", :Xn, "111", :AmXn)
    set_m68k(:clr,   "01000010", :Size2_1, :AmXn)
    set_m68k(:ext,   "010010001", :Size1, "000", :Xn)
    set_m68k(:pea,   "0100100001", :AmXn)
    set_m68k(:andi,  "00000010", :Size2_1, :AmXn)
    set_m68k(:ori,   "00000000", :Size2_1, :AmXn)
    set_m68k(:lsl,   "1110", :Data3, "1", :Size2_1, :Data1, "01", :Xn)
    set_m68k(:lsr,  "1110", :Data3, "0", :Size2_1, :Data1, "01", :Xn)
    set_m68k(:asl,  "1110", :Data3, "1", :Size2_1, :Data1, "00", :Xn)
    set_m68k(:asr,  "1110", :Data3, "0", :Size2_1, :Data1, "00", :Xn)
    set_m68k(:rol, "1110", :Data3, "1", :Size2_1, :Data1, "11", :Xn)
    set_m68k(:ror,  "1110", :Data3, "0", :Size2_1, :Data1, "11", :Xn)
    set_m68k(:swap,  "0100100001000",:Xn)
    ##set_m68k(:or, "1000", :Xn, :Data1,:Size2_1, :AmXn)
    set_m68k(:jmp,   "0100111011", :AmXn)
    set_m68k(:jsr,    "0100111010", :AmXn)
    set_m68k(:bcc,    "0110", :CondMain, :Data8)
    set_m68k(:bra,   "01100000", :Data8)
    set_m68k(:bsr,    "01100001", :Data8)
    set_m68k(:scc,    "0101", :CondAll, "11",:AmXn)
    set_m68k(:dbcc,  "0101", :CondAll, "11001", :Xn)
    set_m68k(:rts,      "0100111001110101")
    set_m68k(:tst,     "01001010", :Size2_1, :AmXn)
    set_m68k(:btst,   "0000100000", :AmXn)
    set_m68k(:btst,   "0000", :Xn, "100", :AmXn)
    set_m68k(:link,    "0100111001010", :Xn)
    set_m68k(:nop,      "0100111001110001")
    set_m68k(:add,     "1101", :Xn, "0", :Size2_1, :AmXn)
    set_m68k(:add,   "1101", :Xn, "1", :Size2_1, :AmXn)
    set_m68k(:adda,   "1101", :Xn, :Size1, "11", :AmXn)
    set_m68k(:addi,    "00000110", :Size2_1, :AmXn)
    set_m68k(:addq,    "0101", :Data3, "0", :Size2_1, :AmXn)
    set_m68k(:sub,     "1001", :Xn, "0", :Size2_1, :AmXn)
    set_m68k(:sub,     "1001", :Xn, "1", :Size2_1, :AmXn)
    set_m68k(:suba,   "1001", :Xn, :Size1, "11", :AmXn)
    set_m68k(:subi,    "00000100", :Size2_1, :AmXn)
    set_m68k(:subq,   "0101", :Data3, "1", :Size2_1, :AmXn)
    set_m68k(:cmp,    "1011", :Xn, "0", :Size2_1, :AmXn)
    set_m68k(:cmpa,  "1011", :Xn, :Size1, "11", :AmXn)
    set_m68k(:cmpi,    "00001100", :Size2_1, :AmXn)
    set_m68k(:move2sr,  "0100011011", :AmXn)
    set_m68k(:movefsr,  "0100000011", :AmXn)
    set_m68k(:moveusp,  "010011100110", :Data1, :Xn)
    set_m68k(:ori2sr,    "0000000001111100")
    
  end
  

end