# coding: utf-8
require 'yaml'
require 'pry'
require 'pry-nav'

def print_g(name, g)
  puts name
  pp g
end

g0 = YAML.load(File.open('input.yml'))

def payload_nonterminas(g)
  n = nil
  ni = Set.new
  while n != ni
    n = ni
    ni = g["nonterminals"].select do |nt|
      ! g["rules"].select do |rule|
        rule["from"].first == nt &&
          rule["to"].all?{|x| (n + g["terminals"]).include?(x)}
      end.empty?
    end.to_set + n
  end
  ni
end

def remove_unreachable_symbols(g)
  v = nil
  vi = Set.new([g["start"]])
  while v != vi
    v = vi
    vi = v + (g["nonterminals"] + g["terminals"]).select do |s|
      ! g["rules"].select do |rule|
        rule["from"].all?{|x| v.include?(x)} &&
          rule["to"].include?(s)
      end.empty?
    end
  end

  {"terminals" => g["terminals"].select{|x| vi.include?(x)},
   "nonterminals" => g["nonterminals"].select{|x| vi.include?(x)},
   "start" => g["start"],
   "rules" => g["rules"].select do |rule|
     (rule["from"] + rule["to"]).all?{|x| vi.include?(x)}
   end
  }
  
end

def remove_notpayload_symbols(g)
#A) Применив к G алгоритм 2.7, получить Ne. Положить
#^i^(Nf|Ne, 2, Pit S), где Рг состоит из правил множества Р,
#содержащих только символы из N^U^.
#B) Применив к Gx алгоритм 2.8, получить G' = (N', 2', P',S).
  ge = payload_nonterminas(g)
  g1 = {"terminals" => g["terminals"],
        "nonterminals" => g["nonterminals"].select{|x| ge.include?(x)},
        "start" => g["start"],
        "rules" => g["rules"].select do |rule|
          (rule["from"] + rule["to"]).all?{|x| (ge + g["terminals"]).include?(x) }
        end
       }
  remove_unreachable_symbols(g1)
end

def to_g1(g)
  g1 = {}
  g1["terminals"] = g["terminals"]
  g1["nonterminals"] = g["nonterminals"].map do |a|
    (g["nonterminals"] + ['$']).map do |x|
      a + x
    end
  end.flatten
  g1["start"] = g["start"] + '$'

  g1["rules"] = (g["nonterminals"] + ['$']).map do |x|
    g['rules'].map do |rule|
      case
      #A -> B => Ax -> Bx
      when rule["from"].count == 1 &&
           rule["to"].count == 1 &&
           g["nonterminals"].include?(rule["from"].first) &&
           g["nonterminals"].include?(rule["to"].first)
        {"from" => [rule["from"].first + x],
         "to"   => [rule["to"].first + x]}
      #A -> BC => Ax -> BxCb
      when rule["from"].count == 1 &&
           rule["to"].count == 2 &&
           g["nonterminals"].include?(rule["from"].first) &&
           rule["to"].all?{|t| g["nonterminals"].include?(t) }
        {"from" => [rule["from"].first + x],
         "to" => [rule["to"].first + x, rule["to"][1] + rule["to"].first]}
      #A -> Ba => Ax -> Bxa
      when rule["from"].count == 1 &&
           rule["to"].count == 2 &&
           g["nonterminals"].include?(rule["from"].first) &&
           g["nonterminals"].include?(rule["to"].first) &&
           g["terminals"].include?(rule["to"][1])
        {"from" => [rule["from"].first + x],
         "to"   => [rule["to"].first + x, rule["to"][1]]}
      #A -> a => Ax -> a
      when rule["from"].count == 1 &&
           rule["to"].count == 1 &&
           g["nonterminals"].include?(rule["from"].first) &&
           g["terminals"].include?(rule["to"].first)
        {"from" => [rule["from"].first + x],
         "to" => rule["to"]}
      else
        raise "non canonical grammar? rule: #{rule}"
      end
    end
  end.flatten
  
  remove_notpayload_symbols(g1)
end

def remove_chained_rules(g)
  old_rules = nil
  rules = g["rules"]
  while old_rules != rules
    old_rules = rules
    rules = old_rules.map do |old_rule|
      if old_rule["to"].count == 1 && g["nonterminals"].include?(old_rule["to"].first)
        old_rules.select{|b_rule| b_rule["from"].first == old_rule["to"].first}.map do |b_rule|
          {"from" => old_rule["from"],
          "to" => b_rule["to"]}
        end
      else
        [old_rule]
      end
    end.flatten
  end
  {"terminals" => g["terminals"],
   "nonterminals" => g["nonterminals"],
   "start" => g["start"],
   "rules" => rules}
end

def to_g2(g1)
  remove_notpayload_symbols remove_chained_rules(g1)
end

def to_g3(g2)
  def gen_alternatives(alternatives)
    return alternatives.first.map{|x| [x]} if alternatives.count == 1
    alternatives.first.map do |alternative|
      gen_alternatives(alternatives[1..-1]).map do |next_alternative|
        [alternative] + next_alternative
      end
    end.flatten(1)
  end

  n3i = g2["nonterminals"].to_set
  new_rules = []
  g2["rules"].select do |rule|
    rule["to"].count == 1 && g2["terminals"].include?(rule["to"].first)
  end.each do |rule|
    new_terminal = rule["from"].first + '^' + rule["to"].first
    n3i += [new_terminal]
    new_rules += [{"from" => [new_terminal], "to" => [rule["to"].first]}]
  end

  g2["nonterminals"].each do |g2_nonterm|
    g2["rules"].select do|rule|
      rule["from"].count == 1 &&
        rule["from"].first == g2_nonterm &&
        (rule["to"].count > 1 || !g2["terminals"].include?(rule["to"].first))
    end.each do|rule|
      to = rule["to"]
      alternatives = to.map do |symbol|
        if g2["terminals"].include? symbol
          [symbol]
        else
          n3i.select{|nt| m = /(.*)\^(.*)/.match(nt); m && m[1] == symbol } + [symbol]
        end
      end
      gen_alternatives(alternatives).each do |alternative|
        new_rules += [{"from" => [g2_nonterm], "to" => alternative}]
      end
    end
  end
  
  remove_notpayload_symbols "terminals" => g2["terminals"],
                            "nonterminals" => n3i,
                            "start" => g2["start"],
                            "rules" => new_rules
end

def to_g4(g3)
  new_rules = g3["rules"].select{|rule| rule["to"].count > 1 || !g3["terminals"].include?(rule["to"].first)}
  g3["rules"].select{|rule| rule["to"].count == 1 && g3["terminals"].include?(rule["to"].first)}.
    group_by{|rule| rule["to"]}.each do |to, from|

    new_rules += [{"from" => from.last["from"], "to" => to}]
    to = from.last["from"]
    from[0..-2].reverse.each do |new_from|
      new_rules += [{"from" => new_from["from"], "to" => to}]
      to = new_from["from"]
    end
  end


  {"terminals" => g3["terminals"],
   "nonterminals" => g3["nonterminals"],
   "start" => g3["start"],
   "rules" => new_rules}
end


print_g("g0", g0)

g1 = to_g1(g0)

print_g('g1', g1)

g2 = to_g2(g1)

print_g('g2', g2)

g3 = to_g3(g2)

print_g('g3', g3)

g4 = to_g4(g3)

print_g('g4', g4)
