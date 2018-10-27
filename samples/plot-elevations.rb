#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# MIT licence

require "net/http"
require 'nokogiri'
require 'json'
require 'optparse'
require 'tmpdir'

include Math

module Geocalc
  RAD = 0.017453292

  def Geocalc.d2r d
    private
    d*RAD
  end

  def Geocalc.r2d r
    private
    r/RAD
  end

  def Geocalc.r2nm r
    private
    ((180*60)/PI)*r
  end

  def Geocalc.csedist lat1,lon1,lat2,lon2
    lat1 = d2r(lat1)
    lon1 = d2r(lon1)
    lat2 = d2r(lat2)
    lon2 = d2r(lon2)
    d=2.0*asin(sqrt((sin((lat1-lat2)/2.0))**2 +
		    cos(lat1)*cos(lat2)*(sin((lon2-lon1)/2.0))**2))
    d = r2nm(d)
    cse =  (atan2(sin(lon2-lon1)*cos(lat2),
		 cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(lon2-lon1))) % (2.0*PI)
    cse = r2d(cse)
    [cse,d]
  end
end

class MReader

  def initialize
    @pf=@of=@hstr=nil

    begin
      opts = OptionParser.new
      opts.banner = %Q/Usage: plot-elevations.rb [options] mission_file

plot-evelations.rb plots a  iNav\/ MW XML mission file (as generated by "mwp",
"ezgui", "mission planner for iNav") against terrain elevation data.

In order to do this, you must have an internet connection, as the elevation data is
obtained from the Bing Maps elevation service. You should provide a home
location (so home -> WP1 and RTH can then be modelled).

Graphical output is a SVG file and requires "gnuplot" be installed. The output
can also be output as a CSV file. If neither a plot file nor an output file
is provided, CSV is written to standard output.

The environment variable MWP_HOME if definded, is also consulted for a home
location (the -h option takes prefence).

/
      opts.separator ""
      opts.separator "Options:"
      opts.on("-p",'--plotfile=FILE', 'Plot file (SVG)') {|o| @pf = o }
      opts.on("-h",'--home=LOCATION', 'Home location as lat,long') {|o| @hstr = o }
      opts.on("-o",'--output=FILE', 'Output file (CSV)') {|o| @of = o }
      rest = opts.parse(ARGV)
      @file = rest[0]
    rescue
      STDERR.puts "Unrecognised option\n\n"
      STDERR.puts opts.help
      exit
    end
    abort "Need a mission file" unless @file
    @tmps=[]
    at_exit {File.unlink(*@tmps) unless @tmps.empty?}
  end

  def mktemp sfx=nil
    tf = File.join Dir.tmpdir,".mi-#{$$}-#{rand(0x100000000).to_s(36)}-"
    tf << sfx if sfx
    @tmps << tf
    tf
  end

  def mkplt infile0, infile1, mx, dists, wps
    str=%Q/
set bmargin 8
set key top right
set key box
set grid
set xtics (#{dists})
set xtics rotate by 45 offset -0.8,-1
set x2tics rotate by 45
set x2tics (#{wps})
set xlabel "Distance"
set bmargin 3

set title "Mission Elevation"
set ylabel "Elevation"
show label
set yrange [ #{mx} : ]
set xrange [ 0 : ]
set datafile separator "\t"

set terminal svg enhanced background rgb 'white' font "Droid Sans,9" rounded
set output \"#{@pf}\"

plot \"#{infile0}\" using 11:12 t "Mission" w lines lt -1 lw 2  lc rgb "red", \"#{infile1}\" using 2:3  t "Terrain" w filledcurve y1=#{mx}  lt -1 lw 2  lc rgb "green"
/
    plt = mktemp ".plt"
    File.open(plt, 'w') {|fh| fh.puts str}
    unless system("gnuplot #{plt}") == true
      abort "Failed to run gnuplot"
    end
  end

  def read
    ipos = []
    dc=[]
    lx=ly=nil
    tdist = 0
    hlat = nil
    hlon = nil
    hstr=(@hstr||ENV['MWP_HOME'])
    if hstr
      hp = hstr.split(',')
      hlat = hp[0].to_f
      hlon = hp[1].to_f
      ipos << { :no => 0, :lat => hlat, :lon => hlon, :alt => 0.0,
	:act=> 'HOME', :p1 => '0', :p2 => '0', :p3 => '0',
	:cse => nil, :dist => 0.0, :tdist => 0.0}
      ly = hlat
      lx = hlon
    end

    doc = Nokogiri::XML(open(@file))
    doc.xpath('//MISSIONITEM|//missionitem').each do |t|
      action=t['action']
      next if action == 'SET_POI'
      no = t['no'].to_i
      lat = t['lat'].to_f
      lon = t['lon'].to_f
      alt = t['alt'].to_i
      if action == 'RTH'
	if hstr.nil?
	  break
	else
	  lat = hlat
	  lon = hlon
	  alt = 0
	end
      end
      c = nil
      d = 0
      if lx and ly
	c,d = Geocalc.csedist ly,lx,lat,lon
	d = d*1852
      end
      lx = lon
      ly = lat
      tdist += d
      ipos << {:no => no, :lat => lat, :lon => lon, :alt => alt, :act => action,
	:p1 => t['parameter1'], :p2 => t['parameter2'], :p3 => t['parameter3'],
	:cse => c, :dist => d, :tdist => tdist}
      break if action == 'POSHOLD_UNLIM'
    end
    ipos
  end

  def pca pts
    lat = 0
    lon = 0
    str=''
    (0...pts.length).step(2).each do |i|
      nlat = (pts[i] * 100000).round.to_i
      nlon = (pts[i+1] * 100000).round.to_i
      dy = nlat - lat
      dx = nlon - lon
      lat = nlat
      lon = nlon

      dy = (dy << 1) ^ (dy >> 31)
      dx = (dx << 1) ^ (dx >> 31)
      index = ((dy + dx) * (dy + dx + 1) / 2) + dy
      while (index > 0)
	rem = index & 31
	index = (index - rem) / 32
	if (index > 0)
	  rem += 32
	end
	str << "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"[rem]
      end
    end
    str
  end

  def get_bing_elevations pts, nsam=0
    act = (nsam <= 0) ? 'List' : 'Polyline'
    rstr="/REST/v1/Elevation/#{act}?points="
    rstr << pca(pts)
    if nsam > 0
      rstr << "&samp=#{nsam}"
    end
    rstr << "&key=Al1bqGaNodeNA71bleJWfjFvW7fApjJOohMSZ2_J0Hpgt4MGdLIYDbgpgCZbZ1xA"
    alts=nil
    http = Net::HTTP.new("dev.virtualearth.net")
    request = Net::HTTP::Get.new(rstr)
    response = http.request(request)
    if response.code == '200'
      jalts=JSON.parse(response.body)
      alts = jalts['resourceSets'][0]['resources'][0]['elevations']
    end
    alts
  end

  def to_info pos
    pa=[]
    pos.each {|p| pa << p[:lat] << p[:lon]}
    alts = get_bing_elevations pa

    fn = @of
    tf = nil
    if fn.nil?
      if @pf
	tf = fn = mktemp ".csv"
      else
	fn = STDOUT.fileno
      end
    end
    mx = 99999
    dists=[]
    wps=[]
    File.open(fn,"w") do |fh|
      fh.puts %w/No Act Lat Lon Alt P1 P2 P3 Course Leg\ (m) Total\ (m) AMSL Elevation/.join("\t")
      pos.each_with_index do |p,j|
	cse =  p[:cse] ? "%.1f" % p[:cse] : nil
        dist = p[:cse] ? "%.0f" % p[:dist] : nil
        md = "%.0f" % p[:tdist]
	agl = alts ? alts[0] + p[:alt]  : nil
	terralt = alts ? alts[j] : nil
	mx = terralt if terralt < mx
	fh.puts [p[:no], p[:act], p[:lat], p[:lon], p[:alt], p[:p1], p[:p2],
	p[:p3],cse, dist, md,agl, terralt].join("\t")
	lbl = case p[:act]
	      when 'HOME'
		'Home'
	      when 'RTH'
		'RTH'
	      else
		"WP%d" % p[:no]
	      end
	wps << "\"#{lbl}\" #{p[:tdist].to_i}"
	dists << p[:tdist].to_i
      end
    end
    unless @pf.nil?
      # needs to calc number
      np = (pos[-1][:tdist]/30).to_i
      np=1023 if np > 1023
      elevs = get_bing_elevations pa, np+1
      dx=pos[-1][:tdist]/np.to_f
      efn = mktemp ".csv"
      File.open(efn,"w") do |fh|
	fh.puts %w/Index Dist Elev/.join("\t")
	0.upto(np) do |j|
	  fh.puts [j, (dx*j).to_i, elevs[j]].join("\t")
	end
      end
      @pf << ".svg" unless @pf.match(/\.svg$/)
      mx = (mx / 10) * 10
      mkplt fn, efn, mx, dists.join(','),wps.join(',')
    end
  end
end

g = MReader.new
pos = g.read
if pos and pos.size > 1
  g.to_info pos
else
  puts "Truncated mission"
end
