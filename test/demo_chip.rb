#Based on Blargg's simple NES-like sound chip emulator
#Note, this sucker takes some time so be patient (1-2 minutes).
require 'lib/blip_buf'
require 'ostruct'

class NesSoundEmu
  include BlipBufBindings
  (SAMPLE_RATE = 44100).freeze
  (CLOCK_RATE  = 1789772.727).freeze
  class Channel < OpenStruct
  end

  def initialize
    @b = blip_new(SAMPLE_RATE/10)
    raise "Unable to create blip buffer (probably out of memory)" if not @b
    blip_set_rates(@b,CLOCK_RATE,SAMPLE_RATE)
    
    @master_vol = 65536/15
    @chan_count = 4

    seed = {:gain=>0,:period=>10,:volume=>0,:timbre=>0,:time=>0,:phase=>0,:amp=>0}
    @sq1 = Channel.new(seed)
    @sq2 = Channel.new(seed)
    @tri = Channel.new(seed)
    @dmc = Channel.new(seed)
    
    @sq1.gain = @master_vol * 26 / 100
    @sq2.gain = @master_vol * 26 / 100
    @tri.gain = @master_vol * 30 / 100
    @dmc.gain = @master_vol * 18 / 100
    
    #run a square wave
    sq_runs = Proc.new do |channel,end_time|
      while channel.time < end_time
        channel.phase = (channel.phase+1)%8
        update_amp(channel,channel.phase < channel.timbre ? 0 : channel.volume)
        channel.time += channel.period
      end
    end
    @sq1.run = sq_runs
    @sq2.run = sq_runs
    
    #run a triangle wave
    @tri.run = Proc.new do |channel,end_time|
      while channel.time < end_time
        if not channel.volume == 0
          channel.phase = (channel.phase+1)%32
          update_amp(channel,channel.phase < 16 ? channel.phase : 31-channel.phase)
        end
        channel.time += channel.period
      end
    end
    
    #run a noise wave
    @dmc.run = Proc.new do |channel,end_time|
      #phase is noise LFSR, which must never be zero
      channel.phase = 1 if channel.phase == 0
      while channel.time < end_time
        if not channel.volume == 0
          channel.phase = ((channel.phase & 1) * channel.timbre) ^ (channel.phase >> 1)
          update_amp(channel, (channel.phase & 1) * channel.volume)
        end
        channel.time += channel.period
      end
    end
  end
  
  #Updates amplitude of waveform in delta buffer
  def update_amp(channel,new_amp)
    delta = new_amp * channel.gain - channel.amp
    channel.amp += delta
    blip_add_delta(@b,channel.time,delta)
  end
  
  #Runs channel to specified time, then writes data to channel's register
  def write_chan(time,channel_index,address,data)
    case channel_index
      when 0
        channel = @sq1
      when 1
        channel = @sq2
      when 2
        channel = @tri
      else
        channel = @dmc
    end
    channel.run.call(channel,time)
    case address
      when 0
        channel.period = data
      when 1
        channel.volume = data
      when 2
        channel.timbre = data
      else
        raise "Corrupt log file"
    end
  end

  def end_frame(end_time)
    @sq1.run.call(@sq1,end_time)
    @sq1.time -= end_time
    
    @sq2.run.call(@sq2,end_time)
    @sq2.time -= end_time
    
    @tri.run.call(@tri,end_time)
    @tri.time -= end_time
    
    @dmc.run.call(@dmc,end_time)
    @dmc.time -= end_time
    
    blip_end_frame(@b,end_time)
    
    #slightly sticky FFI code here
    temp = FFI::MemoryPointer.new(:pointer,1024)
    temp.write_array_of_type(:short,:write_pointer,[1024])
    
    while blip_samples_avail(@b) > 0
      #count is number of samples actually read (in case there
      #were fewer than temp_size samples actually available)
      count = blip_read_samples(@b,temp,1024,0)
      wave_write(temp,count)
    end
  end
  
  def play_log(fname)
    #data index mapping
    time,channel,address,data = 0,1,2,3
    wave_open(SAMPLE_RATE,"out.wav")
    
    file_string = File.new(fname).readlines.each do |line|
      #break if we run out of space!
      break if wave_sample_count >= 120 * SAMPLE_RATE
      
      #In an emulator these writes would be generated by the emulated CPU
      args = line.split.inject([]){|sum,n| sum << n.to_i}
      if args[channel].to_i >= 0 and args[channel].to_i <= 3
        write_chan(args[time],args[channel],args[address],args[data])
      else
        end_frame(args[time])
      end
    end
    wave_close
    blip_delete(@b)
  end
end

NesSoundEmu.new.play_log('test/demo_log.txt')
