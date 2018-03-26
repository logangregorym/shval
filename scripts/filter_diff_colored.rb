#!/usr/bin/ruby -w
#
# Filter and modify a computation graph produced by the "diff" tool.
#
# This file is part of SHVAL. For details, see https://github.com/lam2mo/shval
#
# Please also see the LICENSE file for our notice and the LGPL.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License (as published by the Free
# Software Foundation) version 2.1 dated February 1999.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the IMPLIED WARRANTY OF MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the terms and conditions of the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

# a single differential trace computational graph node
require 'optparse'

$verbose = false;

parser = OptionParser.new do|opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("-v", "--verbose", "Run verbosely") do 
    $verbose = true
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end

end

parser.parse!

# format color
def colorf (color)
  "#{color.to_s(16).rjust(2, '0')}"
end

class DiffNode
  attr_reader :id, :label, :abserr, :relerr, :addr, :disas, :func, :src
  attr_accessor :in, :out, :color

  def initialize (id, label, abserr, relerr, addr="", disas="", func="", src="")
    @id, @label, @abserr, @relerr = id, label, abserr, (relerr ** (1.0/5))
    @addr, @disas, @func, @src = addr, disas, func, src
    @in, @out = [], []
    @color = 0xff;
  end

  # convert to DOT format (including outgoing edges)
  def to_s
    cformat = colorf(@color)
    output =  "#{@id.to_s} [label=\"#{@label.to_s} "
    if ($verbose)
      output += "abserr=#{@abserr.to_s} relerr=#{@relerr.to_s}" +
      " addr=#{@addr} disas='#{@disas}' func='#{@func}' src="
    end
    output += "#{@src}\" style=filled fillcolor=\"" + 
    "\#ff#{cformat}#{cformat}\"];\n" +
    @out.map { |id| "#{@id} -> #{id};" }.join("\n")
  end

end

# a cluster of node ids
class Cluster
  attr_reader :relerr, :ids
  attr_accessor :color

  def initialize(node)
    @ids = [node.id.to_s + ";"]
    @relerr = node.relerr
    @color = 0x00
  end

  def add(node)
    @ids << node.id.to_s + ";"
    @relerr = (@relerr + node.relerr)/2
  end

  def cformat
    "\"\##{colorf(@color)}0000\""
  end

  def to_s
    @ids.join("\n")
  end

end

# data structures
graph = Hash.new      # map: id => node
edges = []            # list of [src,dst] pairs
clusters = Hash.new   # map: name => cluster

# load graph from DOT file

ARGF.each_line do |line|
  if line =~ /^(\d+) \[label="([^ ]*) abserr=([^ ]*) relerr=([^ ]*) addr=([0-9a-f]*) disas='([^']*)' func='([^']*)' src=([^ ]*)"\];$/
    graph[$1.to_i] = DiffNode.new($1.to_i, $2, $3.to_f, $4.to_f, $5, $6, $7, $8)
  elsif line =~ /^(\d+) \[label="([^ ]*) abserr=([^ ]*) relerr=([^ ]*)"\];$/
    graph[$1.to_i] = DiffNode.new($1.to_i, $2, $3.to_f, $4.to_f)
  elsif line =~ /^(\d+) -> (\d+);$/
    edges << [$1.to_i, $2.to_i]       # save edge info for later
  end
end

# remove duplicate edges
edges = edges.uniq

# add all edge information to graph
edges.each do |src,dst|
  graph[src].out << dst if not graph[src].nil?
  graph[dst].in << src if not graph[dst].nil?
end

# for example, keep only nodes with at least incoming or outgoing edge
graph.select! { |id,node| node.in.size > 0 or node.out.size > 0 }

#Find the max absolute error in the graph
max = 0
graph.each do |id,node|
  if (node.relerr > max)
    max = node.relerr
  end
end

# categorize all nodes based on function
graph.each do |id,node|
  func = node.func
  if clusters.has_key?(func)
    clusters[func].add(node)
  else 
    clusters[func] = Cluster.new(node)
  end
end

factor = max == 0 ? 0 : 0xff/max

# color each node accordingly
graph.each do |id,node|
  node.color -= (node.relerr * factor).round
end

# color each cluster accordingly
clusters.each do |name, cluster|
  cluster.color += (cluster.relerr * factor).round
end

# re-output graph in DOT format
puts "digraph trace {"

# output function clusters
count = 0
clusters.each do |name, cluster|
  puts "subgraph cluster_#{count}{"
  puts "color=#{cluster.cformat}"
  puts "label=#{name}"
  puts cluster
  puts "}\n"
  count += 1
end

# output dots and edges
graph.each do |id,node|
  puts node
end
puts "}"

