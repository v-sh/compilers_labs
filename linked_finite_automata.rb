require 'graphviz'

class LinkedFiniteAutomata < Struct.new(:start_state, :end_states)
  class State
    attr_accessor :links
    attr_accessor :back_links #for minimisation algorithm
    attr_accessor :back_links_added
    attr_accessor :mark

    #used in eps removing alg
    attr_accessor :from_states
    attr_accessor :marked
    def initialize(links = [])
      @links = links
      @back_links = []
    end

    def ==(other)
      self.object_id == other.object_id
    end

    def eps_closure
      states = [self]
      begin
        new_states = states.map do |s|
          s.links.select{|l| l.first == :eps}.map{|l| l[1]}
        end.flatten.select do |s|
          !states.include? s
        end.uniq
        states += new_states
      end while !new_states.empty?
      states
    end

    def char_nexts(char)
      links.select{|l| l.first == char}.map{|l| l[1]}.uniq
    end

    def label
      if from_states
        "(" + from_states.map(&:label).join(",") + ")"
      else
        mark
      end
    end
  end

  def attach_to_end(new_end, term = :eps)
    self.end_states.each do |state|
      state.links << [term, new_end]
    end
  end

  def char_nexts(states, char)
    states.map{|state| state.char_nexts char}.flatten.uniq
  end

  def eps_closure(states)
    states.map{|state| state.eps_closure}.flatten.uniq
  end

  def to_dfa
    def make_state(closure)
      s = State.new
      s.from_states = closure
      s
    end
    a = self.class.new
    new_states = [make_state(start_state.eps_closure)]
    a.start_state = new_states.first
    while state = new_states.select{|s| !s.marked}.first
      state.marked = true
      self.class.terminals.each do |terminal|
        term_state = eps_closure(char_nexts(state.from_states, terminal))
        term_state = make_state term_state
        if existed_state = new_states.find{|new_state| new_state.from_states == term_state.from_states}
          term_state = existed_state
        else
          new_states << term_state
        end
        state.links << [terminal, term_state]
      end
    end
    a.end_states = new_states.select{|state| !state.from_states.select{|state| end_states.include? state}.empty?}
    a
  end

  def states
    states = Set[self.start_state]
    begin
      new_states = states.map{|state| state.links.map{|link| link[1]}}.flatten.to_set - states
      states += new_states
    end until new_states.empty?
    states
  end

  def fill_back_links(state)
    return if state.back_links_added
    state.back_links_added = true
    state.links.each do |link|
      link[1].back_links << [link[0], state]
      fill_back_links(link[1])
    end
  end

  def get_equty_states
    # alg 2.6 aho ulman theory of sintax analizing
    fill_back_links(self.start_state)
    @classes = [self.end_states.to_set, self.states - self.end_states.to_set]

    #all j class states, in what we can't go by a
    def pi_j_a(j, a)
      @classes[j].select{|state| !state.back_links.select{|link| link[0] == a}.empty?}
    end

    @indexes = self.class.terminals.map do |a|
      if pi_j_a(0, a).count <= pi_j_a(1, a).count
        {a => Set[0]}
      else
        {a => Set[1]}
      end
    end.reduce(:merge)

    def get_index
      @indexes.find{|k,v| !v.empty?} || [nil, nil]
    end
    #binding.pry
    while (a, i = get_index).first
      i = i.first
      pi = @classes[i]
      @indexes[a].delete(i)
      (0..@classes.count-1).select do |j|
        pj = @classes[j]
        ! pj.select{|q| !q.links.select{|l| l[0] == a && pi.include?(l[1]) }.empty? }.empty?
      end.each do |j|
        pi_j_1 = @classes[i].map do |state|
          state.back_links.select{|link| link[0] == a && @classes[j].include?(link[1])}
        end.reduce(&:+).map{|link| link[1]}.to_set
        continue if pi_j_1.empty?
        pi_j_2 = @classes[j] - pi_j_1
        @classes[j] = pi_j_1
        unless pi_j_2.empty?
          @classes << pi_j_2
          self.class.terminals.each do |a|
            @indexes[a] = if !@indexes.include?(j) && pi_j_a(j,a).count > 0 && pi_j_a(j,a).count <= pi_j_a(@classes.count - 1, a).count
                            @indexes[a] + Set[j]
                          else
                            @indexes[a] + Set[@classes.count - 1]
                          end
          end
        end
      end
    end

    @classes
  end

  def to_canonical
    def make_state(from_states)
      s = State.new
      s.from_states = from_states
      s
    end
    a = self.class.new
    new_states = self.get_equty_states.map{|x| make_state(x)}
    a.start_state = new_states.find{|x| x.from_states.include? self.start_state}
    new_states.each do |new_state|
      new_state.from_states.each do |old_state|
        old_state.links.each do |terminal, l_state|
          unless new_state.links.find{|l| l[0] == terminal}
            new_l_state = new_states.find{|s| s.from_states.include? l_state }
            new_state.links << [terminal, new_l_state]
          end
        end
      end
    end
    a.end_states = new_states.select{|new_state| !new_state.from_states.select{|fs| self.end_states.include? fs}.empty?}

    a
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
        g.add_nodes("#{state.label}#{end_states.include?(state)?'end':''}")
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
    }.output( pdf: "temp.pdf" )
    `evince temp.pdf`
    `rm temp.pdf`
  end

  def test_string(s)
    active_state = start_state
    s.each_char do |terminal|
      puts "parse terminal = #{terminal}"
      active_state = active_state.links.find{|l| l[0] == terminal}[1]
    end
    end_states.include? active_state
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

    def terminals
      ('a'..'z')
    end

    def terminal?(s)
      terminals.include? s
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

    def group_iter terms
      res = []
      cur_term = ""
      terms.each do |term|
        if term == '*'
          cur_term += term
        else
          res << cur_term if cur_term != ""
          cur_term = term
        end
      end
      res << cur_term
      res
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
      terms = group_iter terms
      if terms.count > 1 && !operation?(terms[0]) && !operation?(terms[1])
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
