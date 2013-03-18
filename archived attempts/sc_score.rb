require 'osc-ruby'
require './hd.rb'
require './deltas.rb'
require '../Morphological-Metrics/mm.rb'

sc_dir = '/Applications/SuperCollider'

file = File.open("./path.txt", "r")
list = HD::Ratio.from_s(file.readlines[1])
print "#{list}\n"
base = 440.0 * 2.0 / 3.0

# Set this client to send messages to the scsynth instance
client = OSC::Client.new('localhost', 57110)

# Create a guitar synth at node 1000
node = 1000
client.send(OSC::Message.new('/s_new', 'guitar', node))
client.send(OSC::Message.new('/s_new', 'guitar', node+1))
client.send(OSC::Message.new('/n_set', node+1, 'out', 1))

old_freq = 0.0
new_freq = old_freq

list.each do |r|
  new_freq = (base * r).to_f
  client.send(OSC::Message.new('/n_set', node, 'freq', new_freq))
  client.send(OSC::Message.new('/n_set', node+1, 'freq', old_freq))
  old_freq = new_freq
  sleep 4.0
end

# Kill the synths
client.send(OSC::Message.new('/n_set', node, 'gate', 0))
client.send(OSC::Message.new('/n_set', node+1, 'gate', 0))
