((comment) @comment.documentation
  (#match? @comment.documentation "^///"))

(call_expression
  function: (member_expression
    property: (property_identifier) @function.method))
