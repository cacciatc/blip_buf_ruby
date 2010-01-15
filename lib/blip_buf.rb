require 'ffi'

module BlipBuf
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
