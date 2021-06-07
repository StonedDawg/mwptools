#!/usr/bin/ruby
require 'find'

SENSORS=[:imu, :baro, :mag, :rangefinder]

def find_sensors fn
  s={}
  File.open fn do |fh|
    fh.each do |l|
      next unless l.match(/^\s*#define /)
      SENSORS.each do |ss|
	sn = ss.to_s.upcase
	if m = l.match(/USE_#{sn}_(\S+)/)
	  next if m[1].match(/DATA_READY/)
	  s[ss] ||= []
	  s[ss] << m[1]
	end
      end
    end
  end
  s
end


abort "find_sensors.rb dir version" unless ARGV.size == 2
Dir.chdir(ARGV[0])
puts DATA.read % [ Time.now.strftime("%F"), ARGV[1]]
puts

puts "| Target |  IMU | Baro | Mag  | Rangefinder |"
puts "| ------ | ---- | ---- | ---- | ----------- |"

Find.find('.').select { |f| f =~ /target\.h$/ }.each do |fn|
  next unless fn.match(/src\/main\/target/)
  target=File.dirname(fn).gsub('./','')
  STDERR.puts "#{target} #{fn}\n"
  devs = find_sensors(fn)
  cols = [target]
  mks = Dir.glob "#{target}/CMakeLists.txt"
  SENSORS.each do |ss|
    d = (devs[ss]||[])
    ds=d.sort.uniq
    if d.size != ds.size
      multiple = true
#      STDERR.puts "DS #{target} #{d} #{ds}"
    end
    cols << ds.join(' ')
  end
  textras=[]
  multiple  = false
  unless mks.length.zero?
    File.open(mks[0]) do |f|
      f.each_with_index do |l,n|
        if n > 0
          multiple = true
          if m=l.match(/target_stm32\w+\((\w+)/)
            textras << m[1]
          end
        end
      end
    end
  end
  c0 = cols[0].split('/')[-1]
  cols[0] = c0
  if multiple
    cols[0] = "#{cols[0]} \\*"
    if textras and !textras.empty?
      tstr = textras.join(' ')
      cols[0] = "#{cols[0]} (#{tstr})"
    end
  end
  str = cols.join(" | ")
  puts "| #{str} |"
end
puts

__END__
# Sensor Support

The following table was machine generated by [mwptools' find_sensors.rb](https://raw.githubusercontent.com/stronnag/mwptools/master/src/samples/find_sensors.rb) script on %s against inav %s, E&OE

Targets suffixed by \* indicates that there are (probably) multiple hardware variations covered by one or more firmware images (or just a strange target.h). Additional, related targets are listed in parentheses. The user may check the hardware documentation (or `target.h` / `CMakeLists.txt`) to determine the actual supported sensors.
