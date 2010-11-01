require 'ffi'

module BlipBufBindings
  extend FFI::Library

  ffi_lib "lib/libbb.so"
  
  #some constants
  (BLIP_MAX_RATIO = 1 << 20 ).freeze
  
  #wave writer functions
  attach_function :wave_open, [:int,:string], :void
  attach_function :wave_enable_stereo, [], :void
  attach_function :wave_write, [:pointer,:int], :void
  attach_function :wave_sample_count, [], :int
  attach_function :wave_close, [] , :void
  
  #blip_buf functions
  attach_function :blip_new, [:int], :pointer
  attach_function :blip_set_rates, [:pointer,:double,:double], :void
  attach_function :blip_clear, [:pointer], :void
  attach_function :blip_add_delta, [:pointer,:uint,:int], :void
  attach_function :blip_add_delta_fast, [:pointer,:uint,:int], :void
  attach_function :blip_clocks_needed, [:pointer,:int], :int
  attach_function :blip_end_frame, [:pointer,:uint], :void
  attach_function :blip_samples_avail, [:pointer], :int
  attach_function :blip_read_samples, [:pointer,:pointer,:int,:int], :int
  attach_function :blip_delete, [:pointer], :void
end

#idomaticize
class BlipBuf
  include BlipBufBindings
  
  attr_reader :clock_rate,:sample_rate
  def initialize(sample_count,clock_rate=0,sample_rate=0)
    @b = blip_new(sample_count)
    @clock_rate,@sample_rate = clock_rate,sample_rate
    @time = 0
    raise "Unable to create blip buffer (probably out of memory)" if not @b
    blip_set_rates(@b,@clock_rate,@sample_rate)
  end
  def frame(clocks,time,period,&b)
    @time = time
    while @time < clocks
      b.call
      @time += period
    end
    blip_end_frame(@b,clocks)
    @time
  end
  def clock_rate=(rate)
    @clock_rate = rate
    blip_set_rates(@b,@clock_rate,@sample_rate)
  end
  def sample_rate=(rate)
    @sample_rate = rate
    blip_set_rates(@b,@clock_rate,@sample_rate)
  end
  def available_samples(&b)
    @a ||= FFI::MemoryPointer.new(:pointer,512)
    @a.write_array_of_type(:short,:write_pointer,[512])
    while blip_samples_avail(@b) > 0 do
      count = blip_read_samples(@b,@a,512,0)
      sample = @a
      b.call(sample,count)
    end
  end
  def add_delta(delta)
    blip_add_delta(@b,@time,delta)
  end
  def cleanup!
    blip_delete(@b)
  end
end

module Wav
  def self.record(sample_rate,output,&b)
    BlipBufBindings::wave_open(sample_rate,output)
    b.call
    BlipBufBindings::wave_close
  end
end
