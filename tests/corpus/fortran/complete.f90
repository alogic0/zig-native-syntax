! Free-form Fortran <&>
module vectors
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  type :: vector
    real :: value
  contains
    procedure :: magnitude => vector_magnitude
  end type vector
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
  subroutine report(message)
    character(len=*), intent(in) :: message
  end subroutine report
end module vectors
C fixed-form comment
  100 CONTINUE
     1 total = total + 1
