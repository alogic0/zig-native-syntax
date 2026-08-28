! Free-form Fortran <&>
module vectors
  implicit none
contains
  pure function add(lhs, rhs) result(total)
    real, intent(in) :: lhs, rhs
    real :: total
    character(len=*), parameter :: message = 'don''t split strings'
    integer :: mask = Z'2A'
    total = 1.25_real64 + lhs &
      & + rhs
    if (.true. .and. total >= 0.0) call report(message)
  end function add
end module vectors
C fixed-form comment
  100 CONTINUE
     1 total = total + 1
