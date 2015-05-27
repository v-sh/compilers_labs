# coding: utf-8
#Алгоритм Кока — Янгера — Касами
require 'yaml'
require 'pry'
require 'pry-nav'

def make_table(a, g)
  t = a.each_char.map do |x|
    [
      g["rules"].select do |rule|
        rule["to"].count == 1 &&
          g["terminals"].include?(rule["to"].first) &&
          rule["to"].first == x
        
      end.map{|rule| {rule["from"].first => [rule, 0]}}.reduce(:merge)
    ]
  end
  pp t

  (1...a.length).each do |j|
    puts "\n"
    pp t
    
    (0...a.length - j).each do |i|
      t[i][j] = g["nonterminals"].map do |nonterminal|
        { nonterminal => 
          g["rules"].select do |r|
            r["from"].first == nonterminal && r["to"].count == 2 &&
              r["to"].all?{|x| g["nonterminals"].include? x}
            end.product((0...j).to_a).find do |rule, k|
            b,c = rule["to"]
            t[i][k].keys.include?(b) && t[i + k + 1][j - k - 1].keys.include?(c)
          end
        }
      end.select{|h| h.values.any? }.reduce(:merge)
    end
  end

  t
end

def to_simple_t(t)
  t.map do |row|
    row.map do |e|
      e.keys
    end
  end
end

def get_left_gen(a, t, i, j)
  if j == 0
    t[i][j][a] && [t[i][j][a].first] or raise 'not accepted'
  else
    rule, k = t[i][j][a]
    raise 'not accepted' unless rule
    [rule] +
      get_left_gen(rule["to"][0], t, i, k) +
      get_left_gen(rule["to"][1], t, i + k + 1, j - k - 1) 
  end
end

g = YAML.load(File.open('input.yml'))

a = gets[0..-2]

pp (t = make_table(a,g))

pp to_simple_t(t)

pp get_left_gen(g["start"], t, 0, a.length - 1)


