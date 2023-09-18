!
! routines for sigma levels
!
! revision log :
!
! 16.12.2010    ggu     program partially finished
! 19.09.2011    ggu     new routine set_bsigma()
! 04.11.2011    ggu     new routines for hybrid levels
! 10.11.2011    ggu     adjust depth for hybrid levels
! 11.11.2011    ggu     error check in set_hkv_and_hev()
! 11.11.2011    ggu     in check_hsigma_crossing set zeta levels to const depth
! 18.11.2011    ggu     restructured hybrid - adjustment to bashsigma
! 12.12.2011    ggu     eliminated (stupid) compiler bug (getpar)
! 27.01.2012    deb&ggu adapted for hybrid levels
! 23.02.2012    ccf	bug fix in set_hybrid_depth (no call to get_sigma)
! 05.09.2013    ggu	no set_sigma_hkv_and_hev()
!
! notes :
!
! important files where sigma levels are explicitly needed:
!
!	newini.f		set up of structure
!	subele.f		set new layer thickness
!
!	newbcl.f		for computation of rho
!	newexpl.f		for baroclinic term
!
!	lagrange_flux.f		limit zeta layers to surface layer
!
!********************************************************************
!********************************************************************
!********************************************************************
!--------------------------------------------------------------------
        module sigma_admin
!--------------------------------------------------------------------
        contains
!--------------------------------------------------------------------

	subroutine get_bsigma(bsigma)

! returns bsigma which is true if sigma layers are used

        use para

	implicit none

	logical bsigma

	bsigma = nint(getpar('nsigma')) .gt. 0

	end

!********************************************************************

	subroutine get_sigma(nsigma,hsigma)

        use para

	implicit none

	integer nsigma
	double precision hsigma

	nsigma = nint(getpar('nsigma'))
	hsigma = getpar('hsigma')

	end

!********************************************************************

	subroutine set_sigma(nsigma,hsigma)

        use para
	implicit none

	integer nsigma
	double precision hsigma

	call putpar('nsigma',dble(nsigma))
	call putpar('hsigma',hsigma)

	end 

!********************************************************************
!********************************************************************
!********************************************************************

	subroutine make_sigma_levels(nsigma,hlv)

	implicit none

	integer nsigma
	double precision hlv(nsigma)

	integer l
	double precision hl

	if( nsigma .le. 0 ) stop 'error stop make_sigma_levels: nsigma'

        hl = -1. / nsigma
        do l=1,nsigma
          hlv(l) = l * hl
        end do

	end

!********************************************************************

	subroutine make_zeta_levels(lmin,hmin,dzreg,nlv,hlv)

	implicit none

	integer lmin
	double precision hmin,dzreg
	integer nlv
	double precision hlv(nlv)

	integer l
	double precision hbot

	if( dzreg .le. 0. ) stop 'error stop make_zeta_levels: dzreg'

        hbot = hmin
	if( lmin .gt. 0 ) hlv(lmin) = hbot

        do l=lmin+1,nlv
          hbot = hbot + dzreg
          hlv(l) = hbot
        end do

	end

!********************************************************************

	subroutine set_hybrid_depth(lmax,zeta,htot,hlv,nsigma,hsigma,hlfem)

! sets depth structure and passes it back in hlfem

	implicit none

	integer lmax		!total number of layers
	double precision zeta		!water level
	double precision htot		!total depth (without water level)
	double precision hlv(1)		!depth structure (zeta, sigma or hybrid)
	integer nsigma		!number of sigma levels
	double precision hsigma		!depth of hybrid closure
	double precision hlfem(1)		!converted depth values (return)

	logical bsigma
	integer l,i
	double precision hsig

	bsigma = nsigma .gt. 0

	if( nsigma .gt. 0 ) then
          hsig = min(htot,hsigma) + zeta

	  do l=1,nsigma-1
            hlfem(l) = -zeta - hsig * hlv(l)
	  end do

	  hlfem(nsigma) = -zeta + hsig
	end if

        do l=nsigma+1,lmax
          hlfem(l) = hlv(l)
        end do

	if( nsigma .lt. lmax ) hlfem(lmax) = htot	!zeta or hybrid

! check ... may be deleted

	do l=2,lmax
	  if( hlfem(l) - hlfem(l-1) .le. 0. ) then
	    write(6,*) (hlfem(i),i=1,lmax)
	    stop 'error stop set_hybrid_depth: hlfem'
	  end if
	end do

	end

!********************************************************************

!--------------------------------------------------------------------
        end module sigma_admin
!--------------------------------------------------------------------

