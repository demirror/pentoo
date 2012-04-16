# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="4"
inherit git-2 linux-mod linux-info versionator eutils

##Stable

MY_P=${P/_rc/-rc}
MY_PV=v${PV/_rc/-rc}
MY_PVS=v$(get_version_component_range 1-2)
DESCRIPTION="Stable kernel pre-release wifi subsystem backport"
HOMEPAGE="http://wireless.kernel.org/en/users/Download/stable"
CRAZY_VERSIONING="2"
#SRC_URI="http://www.orbit-lab.org/kernel/${PN}-3.0-stable/${MY_PVS}/${MY_P}-${CRAZY_VERSIONING}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~arm ~x86"
IUSE="apply_cherrypicks apply_crap apply_stable apply_pending atheros_obey_crda bluetooth b43 b44 debugfs debug-driver full-debug injection livecd loadmodules +tarball noleds"

DEPEND="!net-wireless/compat-wireless"
RDEPEND="${DEPEND}
	livecd? ( =sys-kernel/linux-firmware-99999999 )
		!livecd? ( >=sys-kernel/linux-firmware-20110709 )
		sys-fs/udev"

#S="${WORKDIR}"/"${MY_P}"-${CRAZY_VERSIONING}
S="${WORKDIR}/compat-wireless"
RESTRICT="strip"

CONFIG_CHECK="!DYNAMIC_FTRACE"

pkg_setup() {
	linux-mod_pkg_setup
	kernel_is -lt 2 6 27 && die "kernel 2.6.27 or higher is required for compat wireless to be installed"
	kernel_is -gt $(get_version_component_range 1) $(get_version_component_range 2) $(get_version_component_range 3) && die "The version of compat-wireless you are trying to install contains older modules than your kernel. Failing before downgrading your system."
	if kernel_is -eq $(get_version_component_range 1) $(get_version_component_range 2) $(get_version_component_range 3); then
		ewarn "Please report that you saw this message in #pentoo on irc.freenode.net along with your uname -r"
	fi

	#these things are not optional
	linux_chkconfig_module MAC80211 || die "CONFIG_MAC80211 must be built as a _module_ !"
	linux_chkconfig_module CFG80211 || die "CONFIG_CFG80211 must be built as a _module_ !"
	linux_chkconfig_module LIBIPW || ewarn "CONFIG_LIBIPW really should be set or there will be no WEXT compat"

	if use b43; then
		linux_chkconfig_module SSB || die "You need to enable CONFIG_SSB or USE=-b43"
	fi
	if use b44; then
		linux_chkconfig_module SSB || die "You need to enable CONFIG_SSB or USE=-b44"
	fi
}

src_unpack() {
	#EGIT_REPO_URI="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
	EGIT_REPO_URI="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
	EGIT_SOURCEDIR="${WORKDIR}/allstable"
	EGIT_COMMIT="refs/tags/${MY_PV}"
	git-2_src_unpack
	unset EGIT_DIR
	unset EGIT_COMMIT

	#EGIT_REPO_URI="git://git.kernel.org/pub/scm/linux/kernel/git/mcgrof/compat.git"
	EGIT_REPO_URI="git://github.com/mcgrof/compat.git"
	EGIT_SOURCEDIR="${WORKDIR}/compat"
	EGIT_BRANCH="linux-$(get_version_component_range 1).$(get_version_component_range 2).y"
	git-2_src_unpack
	unset EGIT_DIR
	unset EGIT_BRANCH

	#EGIT_REPO_URI="git://git.kernel.org/pub/scm/linux/kernel/git/mcgrof/compat-wireless-2.6.git"
	EGIT_REPO_URI="git://github.com/mcgrof/compat-wireless.git"
	EGIT_SOURCEDIR="${WORKDIR}/compat-wireless"
	EGIT_BRANCH="linux-$(get_version_component_range 1).$(get_version_component_range 2).y"
	git-2_src_unpack
	unset EGIT_DIR
	unset EGIT_BRANCH
}

src_prepare() {
	use apply_cherrypicks && apply="${apply} -n"
	use apply_pending && apply="${apply} -p"
	#use apply_stable && apply="${apply} -s"
	use apply_crap && apply="${apply} -c"

	GIT_TREE="${WORKDIR}/allstable" GIT_COMPAT_TREE="${WORKDIR}/compat" scripts/admin-update.sh${apply} || die

	if use tarball; then
		rm -rf .git/
		set_arch_to_kernel
        	emake KLIB_BUILD="${DESTDIR}"/lib/modules/"${KV_FULL}"/build clean
		find ./ -type f -name *.orig | xargs rm -f
		find ./ -type f -name *.rej  | xargs rm -f
		use apply_cherrypicks && applied="${applied}n"
		use apply_pending && applied="${applied}p"
		#use apply_stable && applied="${applied}s"
		use apply_crap && applied="${applied}c"
		if [ "${applied}" ]; then
			applied="-${applied}"
		fi
		tar -Jcf "${WORKDIR}"/${P}${applied}.tar.xz "${WORKDIR}/compat-wireless/" || die
	fi

	# CONFIG_CFG80211_REG_DEBUG=y
	sed -i '/CFG80211_REG_DEBUG/s/^# *//' "${S}"/config.mk

	#this patch ignores the regulatory settings of an atheros card and uses what CRDA thinks is right
	if use atheros_obey_crda; then
		ewarn "You have enabled atheros_obey_crda which doesn't do what you think."
		ewarn "This use flag will cause the eeprom of the card to be ignored and force"
		ewarn "world roaming on the device until crda provides a valid regdomain."
		ewarn "Short version, this is not a way to break the law, this will automatically"
		ewarn "make your card less functional unless you set a proper regdomain with iw/crda."
		ewarn "Pausing for 10 secs..."
		epatch "${FILESDIR}"/ath_regd_optional.patch
	fi

	if use injection; then
		epatch "${FILESDIR}"/4002_mac80211-2.6.29-fix-tx-ctl-no-ack-retry-count.patch
		epatch "${FILESDIR}"/4004_zd1211rw-2.6.28.patch
	#	epatch "${FILESDIR}"/mac80211.compat08082009.wl_frag+ack_v1.patch
	#	epatch "${FILESDIR}"/4013-runtime-enable-disable-of-mac80211-packet-injection.patch
		epatch "${FILESDIR}"/ipw2200-inject.2.6.36.patch
	fi
	use noleds && epatch "${FILESDIR}"/leds-disable-strict.patch
	use debug-driver && epatch "${FILESDIR}"/driver-debug.patch
	use debugfs && sed -i '/DEBUGFS/s/^# *//' "${S}"/config.mk
	if use full-debug; then
		if use debug-driver ; then
			sed -i '/CONFIG=/s/^# *//' "${S}"/config.mk
		else
			ewarn "Enabling full-debug includes debug-driver."
			sed -i '/DEBUG=/s/^# *//' "${S}"/config.mk
		fi
	fi
#	Disable B44 ethernet driver
	if ! use b44; then
		sed -i '/CONFIG_B44=/s/ */#/' "${S}"/config.mk || die "unable to disable B44 driver"
		sed -i '/CONFIG_B44_PCI=/s/ */#/' "${S}"/config.mk || die "unable to disable B44 driver"
	fi

#	Disable B43 driver
	if ! use b43; then
		sed -i '/CONFIG_B43=/s/ */#/' "${S}"/config.mk || die "unable to disable B43 driver"
		sed -i '/CONFIG_B43_PCI_AUTOSELECT=/s/ */#/' "${S}"/config.mk || die "unable to disable B43 driver"
	#CONFIG_B43LEGACY=
	fi

#	fixme: there are more bluethooth settings in the config.mk
	if ! use bluetooth; then
		sed -i '/CONFIG_COMPAT_BLUETOOTH=/s/ */#/' "${S}"/config.mk || die "unable to disable bluetooth driver"
		sed -i '/CONFIG_COMPAT_BLUETOOTH_MODULES=/s/ */#/' "${S}"/config.mk || die "unable to bluetooth B44 driver"
	fi

}

src_compile() {
	addpredict "${KERNEL_DIR}"
	set_arch_to_kernel
	emake KLIB_BUILD="${DESTDIR}"/lib/modules/"${KV_FULL}"/build || die "emake failed"
}

src_install() {
	if use tarball; then
		insinto /usr/share/${PN}
		doins "${WORKDIR}"/${P}${applied}.tar.xz
	fi

	for file in $(find -name \*.ko); do
		insinto "/lib/modules/${KV_FULL}/updates/$(dirname ${file})"
		doins "${file}"
	done
	dosbin scripts/athenable scripts/b43load scripts/iwl-enable \
		scripts/madwifi-unload scripts/athload scripts/iwl-load \
		scripts/b43enable scripts/unload.sh

	dodir /usr/lib/compat-wireless
	exeinto /usr/lib/compat-wireless
	doexe scripts/modlib.sh

	dodoc README
	dodir /$(get_libdir)/udev/rules.d/
	insinto /$(get_libdir)/udev/rules.d/
	doins udev/50-compat_firmware.rules
	exeinto /$(get_libdir)/udev/
	doexe udev/compat_firmware.sh
}

pkg_postinst() {
	update_depmod
	update_moduledb

	if use !livecd; then
		if use loadmodules; then
			einfo "Attempting to unload modules..."
			#the following line doesn't work, it should be obvious what I want to happen, but ewarn never runs, any help is appreciated
			/usr/sbin/unload.sh | grep -E FATAL && ewarn "Unable to remove running modules, system may be unhappy, reboot HIGHLY recommended!"
			#the preceeding line doesn't work, it should be obvious what I want to happen, but ewarn never runs, any help is appreciated
			einfo "Triggering automatic reload of needed modules..."
			/sbin/udevadm trigger
			einfo "We have attempted to load your new modules for you, this may fail horribly, or may just cause a network hiccup."
			einfo "If you experience any issues reboot is the simplest course of action."
		fi
	fi
	if use !loadmodules; then
		einfo "You didn't USE=loadmodules but you can still attempt to switch to the new drivers without reboot."
		einfo "Run 'unload.sh' then 'udevadm trigger' to cause udev to load the	needed drivers."
		einfo "If unload.sh fails for some reason you should be able to simply reboot to fix everything and load the new modules."
	fi
}

pkg_postrm() {
	remove_moduledb
}
