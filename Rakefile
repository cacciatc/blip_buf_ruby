task :demo do
  exec "ruby test/demo.rb"
end

task :demo_fixed do
  exec "ruby test/demo_fixed.rb"
end

task :demo_chip do
  exec "ruby test/demo_chip.rb"
end

task :demo_gosu do
  exec "ruby test/demo_gosu.rb"
end

task :install do
  src_name = "blip_buf-1.1.0.zip"
  
  require 'open-uri'
  require 'rubygems'
  require 'zip/zip'
  
  #downloading
  if not File.exist?(src_name)
    puts "downloading Blip_Buf source..."
    out = open(src_name, "wb")
    out.write(open("http://blip-buf.googlecode.com/files/blip_buf-1.1.0.zip").read)
    out.close
  end
  break if not File.exist?(src_name)
  
  #unzipping
  if not File.exist?("blip_buf")
    puts "unzipping Blip_Buf..."
    OUTDIR="blip_buf" 
    Zip::ZipFile::open(src_name) do |zip_file| 
      zip_file.each do |e| 
        fpath = File.join(OUTDIR, e.name) 
        FileUtils.mkdir_p(File.dirname(fpath)) 
        zip_file.extract(e, fpath)
      end
    end
  end
  
  puts "building shared library..."
  path = "blip_buf/blip_buf-1.1.0/"
  system("gcc -c #{path}wave_writer.c #{path}blip_buf.c -o #{path}bb.o")
  system("gcc -shared -Wl,-soname,libmean.so.1 -o lib/libbb.so #{path}bb.o")
  
  File.copy("#{path}demo_log.txt","test/")
end