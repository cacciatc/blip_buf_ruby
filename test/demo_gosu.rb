#Based on Blargg's demo_sdl, but using gosu instead (so you'll need gosu installed)
#To use: hold down the left mouse button and wiggle it around, be warned though
#it is noisey!
require 'rubygems'
require 'gosu'

require 'lib/blip_buf'

#this is the same class from the demo_fixed
class SquareWaveGenerator
  include BlipBufBindings
  (SAMPLE_RATE = 44100).freeze
  (CLOCK_RATE  = (SAMPLE_RATE*BLIP_MAX_RATIO).to_f).freeze
  
  attr_accessor :volume,:freq
  def initialize(phase,volume,freq)
    #clock time of next delta and clocks between deltas
    @time,@freq = 0,freq
    #+1 or -1 for phase, and volume
    @phase,@volume = phase,volume
    #current amplitude in delta buffer
    @amp = 0
  end
  
  def run_wave(clocks,b)
    #Clocks for each half of square wave cycle
    period = (CLOCK_RATE / @freq / 2 + 0.5).to_i
    #Convert volume to 16-bit sample range (divided by 2 because it's bipolar)
    volume = (@volume * 65536 / 2 + 0.5).to_i
    #Add deltas that fall before end time
    while @time < clocks
      delta = @phase * volume - @amp
      @amp += delta
      blip_add_delta(b,@time,delta)
      @phase = -@phase
      @time += period
    end
    #adjust for new time frame
    @time -= clocks
  end
  
  def generate_samples(samples,b,clocks)
    run_wave(clocks,b)
  end
end

class FunWindow < Gosu::Window
  include BlipBufBindings
  def initialize
    super(512, 512, false)
    self.caption = "Blip_Buf fun w/ gosu"
    
    @samples = 1024
    @sq1 = SquareWaveGenerator.new(1,0.2,1000)
    @sq2 = SquareWaveGenerator.new(1,0.2,1000)
    
    @b = blip_new(SquareWaveGenerator::SAMPLE_RATE/10)
    raise "Unable to create blip buffer (probably out of memory)" if not @b
    blip_set_rates(@b,SquareWaveGenerator::CLOCK_RATE,SquareWaveGenerator::SAMPLE_RATE)
    
    #slightly sticky FFI code here
    @temp = FFI::MemoryPointer.new(:pointer,@samples)
    @temp.write_array_of_type(:short,:write_pointer,[@samples])
    
    wave_open(SquareWaveGenerator::SAMPLE_RATE,"out.wav")
  end

  def update
    if wave_sample_count < 2 * SquareWaveGenerator::SAMPLE_RATE
      clocks = blip_clocks_needed(@b,@samples)
      @sq1.generate_samples(@samples,@b,clocks)
      @sq2.generate_samples(@samples,@b,clocks)
      
      blip_end_frame(@b,clocks)
      blip_read_samples(@b,@temp,@samples,0)
      wave_write(@temp,@samples)
    else
      wave_close
      Gosu::Song.new(self,"out.wav").play
      wave_open(SquareWaveGenerator::SAMPLE_RATE,"out.wav")
    end
    #mouse controls frequency and volume
    if button_down?(Gosu::Button::MsLeft)
      @sq1.freq = mouse_x / 511.0 * 2000 + 100
      @sq2.freq = mouse_y / 511.0 * 2000 + 100
    end
  end

  def draw
    x,y = mouse_x,mouse_y
    c = Gosu::Color.new(255,255,0,0)
    draw_triangle(x,y+20,c,x+20,y-20,c,x-20,y-20,c)
  end
  
  def button_down(id)
    close if id == Gosu::Button::KbEscape
  end
  
  def close
    blip_delete(@b)
    wave_close
    super
  end
end

window = FunWindow.new
window.show