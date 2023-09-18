!
! $Id: sigmautil.f,v 1.3 2009-09-14 08:20:58 georg Exp $
!
! sigma utilities for output files
!
! revision log :
!
! 07.11.2011	ggu	layer thickness for hybrid coordinates
! 14.11.2011	ggu	new sigma routines copied to this file
! 02.12.2011	ggu	bug fix in init_sigma_info() for nlv == 1
! 16.12.2011	ggu	check for non-initialized data structure (blockdata)
! 19.12.2011	ggu	bug fix in init_sigma_info(): call set_sigma_info()
! 27.01.2012	deb&ggu	changes to get_layer_thickness()
! 27.01.2012	deb&ggu	new routine compute_sigma_info()
! 17.05.2013	ggu	layer_thickness for elem and node, general routine
! 17.05.2013	ggu	new routine get_bottom_of_layer()
! 05.09.2013	ggu	new call interface to get_layer_thickness()
! 25.06.2014	ggu	error stop if computed layer thickness is <= 0
! 15.02.2015	ggu	in get_layer_thickness() handle last layer correctly
! 01.05.2016	ggu	changes in get_layer_thickness(): exit from loop
! 14.05.2016	ggu	substitute blockdata/common with module
!
! notes :
!
! this file is used also in femplot
!
!	get_sigma_info (supdep.f,suplin.f)
!	get_layer_thickness (supdep.f,suplin.f)
!	init_sigma_info (supout.f)
!
!******************************************************************
!******************************************************************
!******************************************************************

!==================================================================
        module sigma
!==================================================================

	implicit none

	integer, save :: nlv_com    = -1
	integer, save :: nsigma_com = -1
	double precision, save ::    hsigma_com = 10000.

!==================================================================
        contains
!==================================================================

!******************************************************************

	subroutine check_sigma_initialized

	implicit none

	if( nlv_com .le. 0 ) then
	  write(6,*) 'nlv_com: ',nlv_com
	  stop 'error stop check_sigma_initialized: not initialized'
	end if

	end

!******************************************************************

	subroutine get_sigma_info(nlv,nsigma,hsigma)

	implicit none

	integer nlv
	integer nsigma
	double precision hsigma

	call check_sigma_initialized

	nlv    = nlv_com
	nsigma = nsigma_com
	hsigma = hsigma_com

	end

!******************************************************************

	subroutine set_sigma_info(nlv,nsigma,hsigma)

	implicit none

	integer nlv
	integer nsigma
	double precision hsigma

	nlv_com    = nlv
	nsigma_com = nsigma
	hsigma_com = hsigma

	end

!******************************************************************

	subroutine init_sigma_info(nlv,hlv)

	implicit none

	integer nlv
	double precision hlv(1)

	integer nsigma
	double precision hsigma

	call compute_sigma_info(nlv,hlv,nsigma,hsigma)
	call set_sigma_info(nlv,nsigma,hsigma)

	end

!******************************************************************
!******************************************************************
!******************************************************************
! next routines can be used without using routines above (common)
!******************************************************************
!******************************************************************
!******************************************************************

	subroutine compute_sigma_info(nlv,hlv,nsigma,hsigma)

	implicit none

	integer nlv		!total number of layers
	double precision hlv(nlv)		!layer structure
	integer nsigma		!total number of sigma layers (return)
	double precision hsigma		!closing depth of hybrid layers (return)

	integer l

!---------------------------------------------------------
! scan depth structure
!---------------------------------------------------------

	hsigma = 10000.
        l = 2                           !HACK for nlv == 1
        if( nlv .eq. 1 ) goto 1

	do l=2,nlv
	  if( hlv(l) .gt. hlv(l-1) ) goto 1
	end do

!---------------------------------------------------------
! only sigma layers found
!---------------------------------------------------------

	if( hlv(nlv) .ne. -1 ) then
          write(6,*) 'nlv,hlv(nlv): ',nlv,hlv(nlv)
	  write(6,*) (hlv(l),l=1,nlv)
	  stop 'error stop compute_sigma_info: internal error (1)'
	end if
	nsigma = nlv
	return

!---------------------------------------------------------
! zeta or hybrid levels found
!
! this algorithm cannot handle hybrid levels with only 2 sigma layers
!---------------------------------------------------------

    1	continue
	if( l .eq. 2 ) then	!only zeta levels
	  nsigma = 0
	else			!hybrid levels
	  nsigma = l
	  hsigma = hlv(l)
	end if

!---------------------------------------------------------
! end of routine
!---------------------------------------------------------

	end

!******************************************************************

	subroutine get_layer_thickness(lmax,nsigma,hsigma,z,h,hlv,hdl)

! returns layer thickness - works also for lmax higher than actual layers
!
! works also for lmax higher than actual layers
! in this case the last values for hl are 0

	implicit none

	integer lmax		!total number of layers
	integer nsigma		!total number of sigma layers
	double precision hsigma		!closing depth of hybrid layers
	double precision z			!water level
	double precision h			!total depth
	double precision hlv(lmax)		!layer structure
	double precision hdl(lmax)		!layer thickness computed (return)

	logical bdebug,berror
	integer ii,l
	double precision zmed
	double precision htot,hsig,htop,hbot

	bdebug = .true.
	bdebug = .false.
	berror = .false.

!---------------------------------------------------------
! compute level structure of sigma levels
!---------------------------------------------------------

	zmed = z
	htot = h
	hsig = min(htot,hsigma) + zmed

	hdl = 0.

	hbot = 0.
	do l=1,nsigma
	  htop = hbot
	  hbot = hlv(l)
	  if( l .eq. nsigma ) hbot = -1.
	  hdl(l) = -hsig * (hbot-htop)
	end do

	if( bdebug ) write(6,*) l,hsig,lmax,nsigma
	if( bdebug ) write(6,*) 'hdl: ',hdl

!---------------------------------------------------------
! compute level structure of zeta and/or hybrid levels
!---------------------------------------------------------

	if( lmax .gt. nsigma ) then		!also zeta coordinates
	  if( lmax .eq. 1 ) then		!just one layer
	    hdl(1) = htot + zmed
	  else
	    hbot = hsigma
	    if( nsigma .eq. 0 ) hbot = -zmed
	    if( bdebug ) write(6,*) nsigma,lmax,zmed,hbot
	    do l=nsigma+1,lmax
	      if( hbot == htot ) exit	!no more layers
	      htop = hbot
	      hbot = hlv(l)
	      if( bdebug ) write(6,*) l,htop,hbot,htot
	      if( hbot .gt. htot ) hbot = htot	!last layer
	      hdl(l) = hbot - htop
	      if( hdl(l) .le. 0. ) berror = .true.
	    end do
	    if( htot > hbot ) hdl(lmax) = hdl(lmax) + htot - hbot
	  end if
	end if
	if( bdebug ) write(6,*) 'hdl: ',hdl

	!if( berror ) goto 99

!---------------------------------------------------------
! end of routine
!---------------------------------------------------------

	return
   99	continue
	write(6,*) 'error computing layer thickness'
	write(6,*) 'lmax,nsigma: ',lmax,nsigma
	write(6,*) 'hsigma,z,h: ',hsigma,z,h
	write(6,*) 'hlv: '
	write(6,*) (hlv(l),l=1,lmax)
	write(6,*) 'hd: '
	write(6,*) (hdl(l),l=1,lmax)
	stop 'error stop get_layer_thickness: 0 thickness'
	end

!******************************************************************

	subroutine get_bottom_of_layer(bcenter,lmax,z,hl,hz)

! computes bottom of layer (or center if bcenter == .true.)

	implicit none

	logical bcenter	!compute depth at center of layer (else bottom)
	integer lmax	!total number of layers
	double precision z		!water level
	double precision hl(lmax)	!layer thickness (from get_layer_thickness)
	double precision hz(lmax)	!depth at layer depth/center (return)

	integer l
	double precision htop,hbot

	htop = -z

	do l=1,lmax
	  hbot = htop + hl(l)
	  hz(l) = hbot
	  if( bcenter ) hz(l) = 0.5*(htop+hbot)
	  htop = hbot
	end do

	end

!******************************************************************

	subroutine adjust_layer_index(nel,nlv,hev,hlv,ilhv)

	integer nel,nlv
	double precision hev(nel)
	double precision hlv(nlv)
	integer ilhv(nel)

	integer ie,l
	integer nlvaux,nsigma
	double precision hsigma,z,h
	double precision hdl(nlv)

	z = 0.
	call get_sigma_info(nlvaux,nsigma,hsigma)

	do ie=1,nel
	  h = hev(ie)
	  call get_layer_thickness(nlv,nsigma,hsigma,z,h,hlv,hdl)
	  do l=1,nlv
	    if( hdl(l) == 0. ) exit
	  end do
	  ilhv(ie) = l - 1
	end do

	end

!******************************************************************
!******************************************************************
!******************************************************************

	subroutine compute_iztype(iztype)

! computes type of vertical coordinates

	implicit none

	integer iztype		!type of vertical coordinates (return)

	integer nlv,nsigma
	double precision hsigma

	call get_sigma_info(nlv,nsigma,hsigma)

	if( nsigma .eq. 0 ) then		! z-coordinates
	  iztype = 1
	else if( nlv .eq. nsigma ) then		! sigma-coordinates
	  iztype = 2
	else					! hybrid-coordinates
	  iztype = 3
	end if

	end
	
!******************************************************************

	subroutine sigma_test

	integer, parameter :: ndim = 5
	integer lmax,nsigma
	double precision hsigma,z,h
	double precision hlv(ndim)
	double precision hdl(ndim)

	hlv = (/2,4,6,8,10/)

	nsigma = 0
	hsigma = 10000.
	z = 0.
	h = 4.2

	lmax = 5
	call get_layer_thickness(lmax,nsigma,hsigma,z,h,hlv,hdl)
	write(6,*) lmax,hdl

	lmax = 2
	call get_layer_thickness(lmax,nsigma,hsigma,z,h,hlv,hdl)
	write(6,*) lmax,hdl

	end

!******************************************************************
!	program sigma_main
!	call sigma_test
!	end
!******************************************************************

!==================================================================
        end module sigma
!==================================================================

