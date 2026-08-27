! Free-form Fortran <&>
module vectors
  implicit none
contains
  pure function add(lhs, rhs) result(total)
    real, intent(in) :: lhs, rhs
    real :: total
    total = lhs + rhs
  end function add
end module vectors
