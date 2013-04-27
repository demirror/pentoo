# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4
USE_RUBY="ruby18 ruby19"

inherit multilib ruby-fakegem

DESCRIPTION="Simple, feature rich ascii table generation library"
HOMEPAGE="http://rubygems.org/gems/terminal-table"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"

#IUSE="hardened"

#ruby_add_rdepend ">=dev-ruby/ethon-0.5.10"

#all_ruby_prepare() {
	#dev-lang/ruby might need the "hardened" flag to enforce the following:
#	if use hardened; then
#		paxctl -v /usr/bin/ruby19 2>/dev/null | grep MPROTECT | grep disabled || ewarn '!!! Typhoeus may only work if ruby19 is MPROTECT disabled\n  Please disable it if required using paxctl -m /usr/bin/ruby19'
#	fi
#}
