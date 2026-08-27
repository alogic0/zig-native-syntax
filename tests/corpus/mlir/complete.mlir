// Vector addition <&>
module attributes {sym_name = "demo"} {
  func.func @add(%lhs: tensor<4xf32>, %rhs: tensor<4xf32>) -> tensor<4xf32> {
    %sum = arith.addf %lhs, %rhs : tensor<4xf32>
    cf.br ^done(%sum : tensor<4xf32>)
  ^done(%result: tensor<4xf32>):
    return %result : tensor<4xf32>
  }
}
