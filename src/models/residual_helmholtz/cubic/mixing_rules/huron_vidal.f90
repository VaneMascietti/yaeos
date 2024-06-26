module yaeos__models_cubic_mixing_rules_huron_vidal
   use yaeos__constants, only: pr, R
   use yaeos__models_ar_genericcubic, only: CubicMixRule
   use yaeos__models_ar_cubic_mixing_base, only: bmix_qmr
   use yaeos__models_ge, only: GeModel
   implicit none

   private

   public :: MHV
   public :: DmixMHV

   type, extends(CubicMixRule) :: MHV
      real(pr), allocatable :: l(:, :)
      real(pr), private, allocatable :: bi(:)
      real(pr), private, allocatable :: B, dBi(:), dBij(:, :)
      class(GeModel), allocatable :: ge
      real(pr) :: q
   contains
      procedure :: Bmix => BmixMHV
      procedure :: D1Mix => D1MixMHV
      procedure :: Dmix => DmixMHV
   end type

   interface MHV
      module procedure :: init
   end interface

contains

   type(MHV) function init(ge, b, lij) result(mixrule)
      !! # Michelsen Modified Huron-Vidal mixing rule
      !! 
      !!
      !! # Description
      !! Detailed description
      !!
      !! # Examples
      !!
      !! ```fortran
      !!  A basic code example
      !! ```
      !!
      !! # References
      !!
      class(GeModel), intent(in) :: Ge
      real(pr), intent(in) :: b(:)
      real(pr), optional, intent(in) :: lij(:, :)

      integer :: i, nc

      nc = size(b)

      mixrule%bi = b
      mixrule%Ge = ge
      if (present(lij)) then
         mixrule%l = lij
      else
         mixrule%l = reshape([(0, i=1, nc**2)], [nc, nc])
      end if
   end function

   subroutine BmixMHV(self, n, bi, B, dBi, dBij)
      use yaeos__models_ar_cubic_mixing_base, only: bmix_linear
      class(MHV), intent(in) :: self
      real(pr), intent(in) :: n(:)
      real(pr), intent(in) :: bi(:)
      real(pr), intent(out) :: B, dBi(:), dBij(:, :)
      call bmix_qmr(n, bi, self%l, b, dbi, dbij)
      ! call bmix_linear(n, bi, b, dbi, dbij)
   end subroutine

   subroutine DmixMHV(self, n, T, &
                      ai, daidt, daidt2, &
                      D, dDdT, dDdT2, dDi, dDidT, dDij &
                      )
      !! # Michelsen Modified Huron-Vidal mixing rule.
      !! Mixing rule at infinite pressure as defined in the book of Michelsen and
      !! Møllerup.
      !!
      !! # Description
      !! At the infinite pressure limit of a cubic equation of state it is possible to
      !! relate teh mixing rule for the attractive term with a excess Gibbs energy
      !! model like NRTL with the expression:
      !!
      !! \[
      !! \frac{D}{RTB}(n, T) = sum_i n_i \frac{a_i(T)}{b_i} + \frac{1}{q}
      !!  \left(\frac{G^E(n, T)}{RT}\right)
      !! \]
      !!
      !! # Examples
      !!
      !! ```fortran
      !!  type(CubicEoS)
      !! ```
      !!
      !! # References
      !!
      class(MHV), intent(in) :: self
      real(pr), intent(in) :: T, n(:)
      real(pr), intent(in) :: ai(:), daidt(:), daidt2(:)
      real(pr), intent(out) :: D, dDdT, dDdT2, dDi(:), dDidT(:), dDij(:, :)
      real(pr) :: f, fdt, fdt2, fdi(size(n)), fdit(size(n)), fdij(size(n), size(n))

      real(pr) :: b, bi(size(n)), dbi(size(n)), dbij(size(n), size(n))
      real(pr) :: Ge, GeT, GeT2, Gen(size(n)), GeTn(size(n)), Gen2(size(n), size(n))

      real(pr) :: totn !! Total number of moles
      real(pr) :: dot_n_logB_nbi
      real(pr) :: logB_nbi(size(n)) !! \(\ln \frac{B}{n b_i}\)
      real(pr) :: dlogBi_nbi(size(n))
      real(pr) :: d2logBi_nbi(size(n), size(n))

      integer :: i, j, l, nc
      real(pr) :: q

      nc = size(n)
      totn = sum(n)

      q = self%q
      bi = self%bi

      call self%ge%excess_gibbs( &
         n, T, Ge=Ge, GeT=GeT, GeT2=GeT2, Gen=Gen, GeTn=GeTn, Gen2=Gen2 &
         )
      call self%Bmix(n, bi, B, dBi, dBij)
      logb_nbi = log(B/(totn*bi))
      dot_n_logB_nbi = dot_product(n, logB_nbi)

      do i = 1, nc
         dlogBi_nbi(i) = logB_nbi(i) + sum(n*dBi(i))/B - 1
      end do

      do i = 1, nc
      do j = 1, nc
         !TODO: Need to figure out this derivative
         d2logBi_nbi(i, j) = dlogBi_nbi(j) &
                             + (sum(n*dBij(i, j)) + dBi(i))/B &
                             - totn*dBi(i)*dBi(j)/B**2
      end do
      end do

      autodiff: block
         !! Autodiff injection until we can decipher this derivative
         use hyperdual_mod
         type(hyperdual) :: hB
         type(hyperdual) :: hdot_ln_B_nbi
         type(hyperdual) :: hn(nc)

         integer :: ii, jj
         hn = n

         do i = 1, nc
            do j = i, nc
               hn = n
               hn(i)%f1 = 1
               hn(j)%f2 = 1

               hB = 0._pr
               do ii=1,nc
                  do jj=1,nc
                     hB = hB &
                        + (hn(ii)*hn(jj)) &
                        * 0.5_pr * (bi(ii) + bi(jj)) * (1._pr - self%l(ii, jj))
                  end do
               end do
               hB = hB/sum(hn)

               hdot_ln_B_nbi = sum(hn*log(hB/(sum(hn)*bi)))
               
               d2logBi_nbi(i, j) = hdot_ln_B_nbi%f12
               d2logBi_nbi(j, i) = hdot_ln_B_nbi%f12
            end do
         end do
      end block autodiff

      f = sum(n*ai/bi) + (Ge + R*T*dot_n_logB_nbi)/q
      fdt = sum(n*daidt/bi) + (GeT + R*dot_n_logB_nbi)/q
      fdt2 = sum(n*daidt2/bi) + (GeT2)/q

      fdi = ai/bi + (1._pr/q)*(GeN + R*T*(dlogBi_nbi))
      fdit = daidt/bi + (1._pr/q)*(GeTn + R*(dlogBi_nbi))

      do i = 1, nc
         do j = 1, nc
            fdij(i, j) = R*T*(d2logBi_nbi(i, j))
            fdij(i, j) = 1/q*(fdij(i, j) + GeN2(i, j))
            fdij(i, j) = &
               dBi(j)*fdi(i) + B*fdij(i, j) + fdi(j)*dBi(i) + f*dBij(i, j)
         end do
      end do

      dDi = B*fdi + f*dBi
      dDidT = B*fdiT + fdT*dBi

      D = f*B
      dDdT = fdT*B
      dDdT2 = fdT2*B
      dDij = fdij

   contains
      real(pr) function dlB(n, bi)
         real(pr), intent(in) :: n(:), bi(:)
         real(pr) :: logb_nbi(size(n))

         real(pr) :: B, dBi(size(n)), dBij(size(n), size(n))
         real(pr) :: totn

         call self%Bmix(n, bi, B, dBi, dBij)
         totn = sum(n)
         logb_nbi = log(B/(totn*bi))
         dlB = dot_product(n, logB_nbi)
      end function
   end subroutine

   subroutine D1MixMHV(self, n, d1i, D1, dD1i, dD1ij)
      use yaeos__models_ar_cubic_mixing_base, only: d1mix_rkpr
      class(MHV), intent(in) :: self
      real(pr), intent(in) :: n(:)
      real(pr), intent(in) :: d1i(:)
      real(pr), intent(out) :: D1
      real(pr), intent(out) :: dD1i(:)
      real(pr), intent(out) :: dD1ij(:, :)
      call d1mix_rkpr(n, d1i, D1, dD1i, dD1ij)
   end subroutine D1MixMHV
end module yaeos__models_cubic_mixing_rules_huron_vidal
