// Instruction definition <&>
class Operand<string name> {
  string Name = name;
  bits<8> Encoding = 0xff;
}

def RegisterA : Operand<"a">;
def ADD : Instruction {
  let Pattern = (add $lhs, $rhs);
  let Decoder = [{ return decode(value); }];
}
