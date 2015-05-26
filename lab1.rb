require_relative 'linked_finite_automata'
require 'pry'
require 'pry-nav'

a = LinkedFiniteAutomata::regex_to_nfa("(a+b)*abb")
a.visualize
b = a.to_dfa
b.visualize
c = b.to_canonical
c.visualize

puts "input str"
puts c.test_string(gets.gsub(/\s/, "")) ? "accepted" : "notaccepted"
