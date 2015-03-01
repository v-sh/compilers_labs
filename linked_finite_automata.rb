require 'graphviz'

class LinkedFiniteAutomata < Struct.new(:start_state, :end_states)
  class State
    attr_accessor :links
    attr_accessor :mark
    def initialize(links = [])
      @links = links
    end

    def ==(other)
      self.object_id == other.object_id
    end
  end

  def attach_to_end(new_end, term = :eps)
    self.end_states.each do |state|
      state.links << [term, new_end]
    end
  end

  def visualize
    GraphViz::new( :G, :type => :digraph ) { |g|
      states = [start_state]
      begin
        new_states = states.map do |s|
          s.links.map{|l| l[1]}
        end.flatten.select do |s|
          !states.include? s
        end.uniq
        states += new_states
      end while !new_states.empty?
      
      nodes = states.each_with_index.map do |state, i|
        state.mark = i
        g.add_nodes("#{i}")
      end

      states.each_with_index do |state, i|
        state.links.group_by {|l| l[1]}.each do |end_state, links|
          mark = links.map(&:first).uniq.join(',')
          start_node = nodes[state.mark]
          end_node = nodes[end_state.mark]
          
          edge = g.add_edges(start_node, end_node)
          edge[:label] = mark
        end
      end
    }.output( :png => "temp.png" )
    `eog temp.png`
    `rm temp.png`
  end
  
  class << self

    def create_empty
      a = self.new
      a.start_state = (a.end_states = [State.new]).first
      a
    end

    def create_terminal(terminal)
      a = self.new
      a.end_states = [State.new]
      a.start_state = State.new([[terminal, a.end_states.first]])
      a
    end

    def create_sum(first, second)
      a = self.new
      a.start_state = State.new
      a.end_states = [State.new]

      a.start_state.links = [[:eps, first.start_state],
                             [:eps, second.start_state]
                            ]
      first.attach_to_end a.end_states.first
      second.attach_to_end a.end_states.first
      a
    end

    def create_concat first, second
      a = self.new
      a.start_state = first.start_state
      first.attach_to_end second.start_state
      a.end_states = second.end_states
      a
    end

    def create_iter op
      a = self.new
      a.end_states = [State.new]
      a.start_state = State.new([[:eps, op.start_state],
                                        [:eps, a.end_states.first]])
      op.attach_to_end op.start_state
      op.attach_to_end a.end_states.first
      a
    end

    def terminal?(s)
      ('a'..'z').include? s
    end

    def regex_to_nfa(regex)
      puts "DEBUG: regex = #{regex}"
      regex = remove_brackets regex
      case
      when regex.empty?
        self.create_empty
      when terminal?(regex)
        self.create_terminal regex
      when ops = parse_sum(regex)
        op1 = regex_to_nfa ops[0]
        op2 = regex_to_nfa ops[1]
        self.create_sum op1, op2
      when ops = parse_concat(regex)
        op1 = regex_to_nfa ops[0]
        op2 = regex_to_nfa ops[1]
        self.create_concat op1, op2
      when op = parse_iter(regex)
        op = regex_to_nfa op
        self.create_iter op
      else
        raise 'regex analyse error'
      end
    end

    def operation?(char)
      %w{* +}.include? char
    end
    
    def parse_brackets(regex)
      stack = []
      terms = []
      cur_term = ""
      regex.each_char do |char|
        case
        when char == '('
          stack.push char
          cur_term << char
        when char == ')'
          raise 'error unweighted brackets' if stack.pop != '('
          cur_term << char
          if stack.empty?
            terms << cur_term
            cur_term = ""
          end
        when terminal?(char) || operation?(char)
          if stack.empty?
            terms << char
          else
            cur_term << char
          end
        end
      end
      terms
    end

    def parse_sum(regex)
      terms = parse_brackets regex
      if plus_i = terms.find_index('+')
        op1 = terms[0..plus_i-1].join
        op2 = terms[plus_i+1..-1].join
        return op1, op2
      end
    end

    def parse_concat(regex)
      terms = parse_brackets regex
      if !operation?(terms[0]) && !operation?(terms[1])
        op1 = terms[0]
        op2 = terms[1..-1].join
        return op1, op2
      end
    end

    def parse_iter(regex)
      terms = parse_brackets regex
      if terms.length == 2 && terms[1] == '*'
        terms[0]
      end
    end
    
    def remove_brackets_try(regex)
      if regex[0] == '(' && regex[-1] == ')' && parse_brackets(regex).count == 1
        [regex[1..-2], true]
      else
        [regex, false]
      end
    end

    def remove_brackets(regex)
      begin
        regex, cont = remove_brackets_try(regex)
      end while cont
      regex
    end
  end
end
