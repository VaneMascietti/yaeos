module ar_interface
   !! Generic interfaces to an ArModel compatible with legacy codes, using
   !! pointers.
   use constants, only: pr, R
   use iso_fortran_env, only: error_unit

   implicit none

   procedure(Ares), pointer :: ar_fun
   procedure(initial_volume), pointer :: v0

   abstract interface
      subroutine Ares(z, v, t, Ar, ArV, ArTV, ArV2, Arn, ArVn, ArTn, Arn2)
         !! Residual Helmholtz model interface
         use constants, only: pr
         real(pr), intent(in) :: z(:)
         real(pr), intent(in) :: v, t
         real(pr), intent(out) :: Ar, ArV, ArTV, ArV2
         real(pr), dimension(size(z)), intent(out) :: Arn, ArVn, ArTn
         real(pr), intent(out) :: Arn2(size(z), size(z))
      end subroutine

      function initial_volume(z, p, t, root)
         use constants, only: pr
         real(pr) :: z(:)
         real(pr) :: p
         real(pr) :: t
         character(len=*), optional :: root
      end function
   end interface

contains
   subroutine check()
      use iso_fortran_env, only: error_unit
      if (.not. associated(ar_fun)) then
         write(error_unit, *) "ERORR: Ar Function not associated"
         call exit(1)
      end if

      ! if (.not. associated(v0)) then
      !    write(error_unit, *) "ERORR: v0 Function not associated"
      !    call exit(1)
      ! end if
   end subroutine
end module
