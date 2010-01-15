#Based off Blargg's demo that creates a square wave!
require 'lib/blip_buf'

class SquareWaveGenerator
  include BlipBuf
  (SAMPLE_RATE = 44100).freeze
  (CLOCK_RATE  = 3579545.45).freeze
  
  attr_accessor :volume,:period
  def initialize(phase,volume)
    #clock time of next delta and clocks between deltas
    @time,@period = 0,1
    #+1 or -1 for phase, and volume
    @phase,@volume = phase,volume
    #current amplitude in delta buffer
    @amp = 0
    #blip buffer
    @b = blip_new(SAMPLE_RATE/10)
    raise "Unable to create blip buffer (probably out of memory)" if not @b
    blip_set_rates(@b,CLOCK_RATE,SAMPLE_RATE)
  end
  
  def run_wave(clocks)
    #Add deltas that fall before end time
    while @time < clocks
      delta = @phase * @volume - @amp
      @amp += delta
      blip_add_delta(@b,@time,delta)
      @phase = -@phase
      @time += @period
    end
    blip_end_frame(@b,clocks)
    #adjust for new time frame
    @time -= clocks
  end
  
  def flush_samples
    #If we only wanted 512-sample chunks, never smaller, we would
    #do >= 512 instead of > 0. Any remaining samples would be left
    #in buffer for next time.
    
    #slightly sticky FFI code here
    temp = FFI::MemoryPointer.new(:pointer,512)
    temp.write_array_of_type(:short,:write_pointer,[512])
    
    while blip_samples_avail(@b) > 0 do
      #count is number of samples actually read (in case there
      #were fewer than temp_size samples actually available)
      count = blip_read_samples(@b,temp,512,0)
      wave_write(temp,count)
    end
  end
  
  def clean_up!
    blip_delete(@b)
  end
end

#run generator
sq = SquareWaveGenerator.new(1,0)

BlipBuf::wave_open(SquareWaveGenerator::SAMPLE_RATE,"out.wav")

while BlipBuf::wave_sample_count < 2 * SquareWaveGenerator::SAMPLE_RATE
  #Generate 1/60 second each time through loop
	clocks = (SquareWaveGenerator::CLOCK_RATE / 60).to_i
		
  #We could instead run however many clocks are needed to get a fixed number
  #of samples per frame:
  #int samples_needed = sample_rate / 60;
  #clocks = blip_clocks_needed( blip, samples_needed );
  sq.run_wave(clocks)
  
  sq.flush_samples

  #Slowly increase volume and lower pitch
  sq.volume += 100
  sq.period += sq.period / 28 + 3
end

BlipBuf::wave_close()
sq.clean_up!