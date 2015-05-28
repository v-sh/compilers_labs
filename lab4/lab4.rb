require 'pry-nav'

class ParseCtx
  attr_accessor :a, :pos, :rules

  def initialize(a, pos = 0, rules = [])
    @a = a
    @pos = pos
    @rules = rules
  end

  def clone
    self.class.new(@a, @pos, @rules.clone)
  end

  def cur_char
    @a[@pos]
  end

  def next_char
    @pos += 1
  end

  def ended?
    @a.length <= @pos
  end

  def push_rule(rule)
    @rules << rule
  end
end

def parse_exp(ctx)
  !ctx.ended? &&
  (
    (s_ctx = ctx.clone).push_rule('exp -> s_exp rel_op s_exp') && (s_ctx = parse_s_exp(s_ctx)) && (s_ctx = parse_rel_op(s_ctx)) && (s_ctx = parse_s_exp(s_ctx)) ||

    (s_ctx = ctx.clone).push_rule('exp -> s_exp') && (s_ctx = parse_s_exp(s_ctx))
  ) && s_ctx || nil
end

def parse_s_exp(ctx)
  !ctx.ended? &&
    (
      #(s_ctx = ctx.clone).push_rule('s_exp -> id') && ctx.cur_char == 'id' && s_ctx.next_char

      (s = ctx.clone).push_rule('s_exp -> sign term s_exp_r') && (s = parse_sign(s)) && (s = parse_term(s)) && (s = parse_s_exp_r(s)) ||
      (s = ctx.clone).push_rule('s_exp -> term s_exp_r') && (s = parse_term(s)) && (s = parse_s_exp_r(s)) ||
      (s = ctx.clone).push_rule('s_exp -> sign term') && (s = parse_sign(s)) && (s = parse_term(s)) ||
      (s = ctx.clone).push_rule('s_exp -> term') && (s = parse_term(s))
    ) && s || nil
end

def parse_s_exp_r(ctx)
  !ctx.ended? &&
    (
      (s = ctx.clone).push_rule('s_exp_r -> add_oper term s_exp_r') && (s = parse_add_oper(s)) && (s = parse_term(s)) && (s = parse_s_exp_r(s)) ||
      (s = ctx.clone).push_rule('s_exp_r -> add_oper term') && (s = parse_add_oper(s)) && (s = parse_term(s))
    ) && s || nil
end

def parse_term(ctx)
  !ctx.ended? &&
    (
      (s = ctx.clone).push_rule('term -> factor term_r') && (s = parse_factor(s)) && (s = parse_term_r(s)) ||
      (s = ctx.clone).push_rule('term -> factor') && (s = parse_factor(s))
    ) && s || nil
end

def parse_term_r(ctx)
  !ctx.ended? &&
    (
      (s = ctx.clone).push_rule('term_r -> mul_oper factor term_r') && (s = parse_mul_oper(s)) && (s = parse_factor(s)) && (s = parse_term_r(s)) ||
      (s = ctx.clone).push_rule('term_r -> mul_oper factor') && (s = parse_mul_oper(s)) && (s = parse_factor(s))
    ) && s || nil
end

def parse_factor(ctx)
  pp ctx
  !ctx.ended? &&
    (
      (s = ctx.clone).push_rule('factor -> id') && s.cur_char == 'id' && s.next_char ||
      (s = ctx.clone).push_rule('factor -> const') && s.cur_char == 'const' && s.next_char ||
      (s = ctx.clone).push_rule('factor -> ( s_exp )') && s.cur_char == '(' && s.next_char && (s = parse_s_exp(s)) && s.cur_char == ')' && s.next_char ||
      (s = ctx.clone).push_rule('factor -> not factor') && s.cur_char == 'not' && s.next_char && (s = parse_factor(s))
    ) && s || nil
end

def parse_rel_op(ctx)
  !ctx.ended? &&
  (
    (s_ctx = ctx.clone).push_rule("rel_op -> #{ctx.cur_char}") && ['<>', '<', '<=', '>', '>='].include?(s_ctx.cur_char) && s_ctx.next_char
  ) && s_ctx || nil
end

def parse_sign(ctx)
  !ctx.ended? &&
  (
    (s_ctx = ctx.clone).push_rule("sign -> #{ctx.cur_char}") && ['+', '-'].include?(s_ctx.cur_char) && s_ctx.next_char
  ) && s_ctx || nil
end

def parse_add_oper(ctx)
  !ctx.ended? &&
  (
    (s_ctx = ctx.clone).push_rule("add_oper -> #{ctx.cur_char}") && ['-', '+', 'or'].include?(s_ctx.cur_char) && s_ctx.next_char
  ) && s_ctx || nil
end

def parse_mul_oper(ctx)
  !ctx.ended? &&
  (
    (s_ctx = ctx.clone).push_rule("mul_oper -> #{ctx.cur_char}") && ['*', '/', 'div', 'mod', 'and'].include?(s_ctx.cur_char) && s_ctx.next_char
  ) && s_ctx || nil
end

def parse_block(ctx)
  !ctx.ended? &&
    (
      (s = ctx.clone).push_rule("block -> begin oper_list end") && s.cur_char == 'begin' && s.next_char && (s = parse_oper_list(s)) && s.cur_char == 'end' && s.next_char
    ) && s || nil
end

def parse_oper_list(ctx)
  !ctx.ended? &&
    (
      (s = ctx.clone).push_rule("oper_list -> oper oper_list_r") && (s = parse_oper(s)) && (s = parse_oper_list_r(s)) ||
      (s = ctx.clone).push_rule("oper_list -> oper") && (s = parse_oper(s))
    ) && s || nil
end

def parse_oper_list_r(ctx)
  !ctx.ended? &&
    (
      (s = ctx.clone).push_rule("oper_list_r -> ; oper oper_list_r") && s.cur_char == ';' && s.next_char && (s = parse_oper(s)) && (s = parse_oper_list_r(s)) ||
      (s = ctx.clone).push_rule("oper_list_r -> ; oper") && s.cur_char == ';' && s.next_char && (s = parse_oper(s))
    ) && s || nil
end

def parse_oper(ctx)
  !ctx.ended? &&
    (
      (s = ctx.clone).push_rule("oper -> id = exp") && s.cur_char == 'id' && s.next_char && s.cur_char == '=' && s.next_char && (s = parse_exp(s))
    ) && s || nil
end


a = gets.split

ctx = ParseCtx.new(a)


#sample: begin id = id > const ; id = const ; id = id + const ; id = const > ( const + id ) end
pp parse_block(ctx)
