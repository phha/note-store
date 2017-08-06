# Copyright (C) 2012 - 2017 Jason A. Donenfeld <Jason@zx2c4.com> and
# Philipp Hack <philipp.hack@gmail.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

GETOPT="$(brew --prefix gnu-getopt 2>/dev/null || { which port &>/dev/null && echo /opt/local; } || echo /usr/local)/bin/getopt"
