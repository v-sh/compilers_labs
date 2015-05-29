require 'pry-nav'

bin_operators = [%w{* / div mod and}, %w{+ - or}, %w{<> < <= > >=}]
unary_operators = [%w{not}]
consts = [%w{id const}]
operators = consts.flatten + bin_operators.flatten + unary_operators.flatten + ['(', ')'] + ['$']

table = operators.map do |oper1|
  {
    oper1 => 
    operators.map do |oper2|
      {
        oper2 => case
                 when bin_operators.flatten.include?(oper1) && bin_operators.flatten.include?(oper2)
                   precedence1 = - bin_operators.find_index{|prec_group| prec_group.include?(oper1)}
                   precedence2 = - bin_operators.find_index{|prec_group| prec_group.include?(oper2)}
                   if precedence1 > precedence2
                     '>'
                   elsif precedence1 < precedence2
                     '<'
                   else # = always left associative
                     '>'
                   end
                 else nil
                 end
      }
    end.reduce(:merge)
  }
end.reduce(:merge)


(bin_operators.flatten + unary_operators.flatten).each do |oper|
  consts.flatten.each do |const|
    table[oper][const] = '<'
    table[const][oper] = '>'

    table[oper]['('] = '<'
    table['('][oper] = '<'
    table[oper][')'] = '>'
    table[')'][oper] = '>'

    table['$'][oper] = '<'
    table[oper]['$'] = '>'
  end
end

table['('][')'] = '='
table['$']['('] = '<'

consts.flatten.each do |const|
  table['$'][const] = '<'
  table[const]['$'] = '>'

  table['('][const] = '<'
  table[const][')'] = '>'
end

table['(']['('] = '<'
table[')']['$'] = '>'
table[')'][')'] = '>'

(bin_operators.flatten).each do |oper|
  table[oper]['not'] = '<'
  table['not'][oper] = '>'
end

pp table

def get_polish(s, table)
  res = []
  s += ['$']
  stack = ['$']
  st = 0
  i = 0
  while st > 0 || s[i] != '$'
    puts "stack = #{stack}, s[i] = #{s[i]}, #{[st]}, #{res}, table= #{table[stack[st]][s[i]]} "
    case table[stack[st]][s[i]]
    when '<', '='
      stack[st += 1] = s[i]
      i += 1
    when '>'
      begin
        res += [stack[st]] if ! ['(', ')'].include? stack[st]
        st -= 1
        puts "d: stack = #{stack}, st = #{st}"
      end until table[stack[st]][stack[st + 1]] == '<'
    else
      return nil
    end
  end
  res
end


s = gets.split

puts get_polish(s, table).join(" ")

