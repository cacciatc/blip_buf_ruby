#Based off Blargg's demo that creates a 2 square waves!
require 'lib/blip_buf'

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

include BlipBufBindings
#blip buffer
b = blip_new(SquareWaveGenerator::SAMPLE_RATE/10)
raise "Unable to create blip buffer (probably out of memory)" if not b
blip_set_rates(b,SquareWaveGenerator::CLOCK_RATE,SquareWaveGenerator::SAMPLE_RATE)

#run generators
sq1 = SquareWaveGenerator.new(1,0.0,16000)
sq2 = SquareWaveGenerator.new(1,0.5,1000)

samples = 1024

wave_open(SquareWaveGenerator::SAMPLE_RATE,"out.wav")

#slightly sticky FFI code here
temp = FFI::MemoryPointer.new(:pointer,samples)
temp.write_array_of_type(:short,:write_pointer,[samples])

while wave_sample_count < 2 * SquareWaveGenerator::SAMPLE_RATE

  clocks = blip_clocks_needed(b,samples)
  sq1.generate_samples(samples,b,clocks)
  sq2.generate_samples(samples,b,clocks)
  
  blip_end_frame(b,clocks)
  blip_read_samples(b,temp,samples,0)
  wave_write(temp,samples)

  #Slowly increase volume and lower pitch
  sq1.volume += 0.005
  sq1.freq   *= 0.950
  
  sq2.volume -= 0.002
  sq2.freq   *= 1.010
end

wave_close()

blip_delete(b)