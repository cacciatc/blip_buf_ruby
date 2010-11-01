#Based off Blargg's demo that creates a square wave!
require 'lib/blip_buf'

class SquareWaveGenerator
  include BlipBufBindings
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
    
    @b2 = BlipBuf.new(SAMPLE_RATE/10,CLOCK_RATE,SAMPLE_RATE)
  end
  
  def run_wave(clocks)
    #Add deltas that fall before end time
    @time = @b2.frame(clocks,@time,@period) do
        delta = @phase * @volume - @amp
        @amp += delta
        @b2.add_delta(delta)
        @phase = -@phase
    end
    
    #adjust for new time frame
    @time -= clocks
  end
  
  def flush_samples
    #If we only wanted 512-sample chunks, never smaller, we would
    #do >= 512 instead of > 0. Any remaining samples would be left
    #in buffer for next time.
    
    @b2.available_samples do |sample,count|
      wave_write(sample,count)
    end
  end
  
  def clean_up!
    @b2.cleanup!
  end
end

#run generator
sq = SquareWaveGenerator.new(1,0)

Wav::record(SquareWaveGenerator::SAMPLE_RATE,"out.wav") do
  while BlipBufBindings::wave_sample_count < 2 * SquareWaveGenerator::SAMPLE_RATE
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
end

sq.clean_up!