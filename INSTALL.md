INSTALLATION
============

Simply typing

    make install

should install notes to the standard locations.

The makefile is aware of the following environment variables:

* `PREFIX`      default: `/usr`
* `DESTDIR`     default: 
* `BINDIR`      default: `$(PREFIX)/bin`
* `LIBDIR`      default: `$(PREFIX)/lib`
* `MANDIR`      default: `$(PREFIX)/share/man`
* `SYSCONFDIR`  default: `/etc`

Completion Files
----------------

The install target will automatically determine the existance
of bash, and zsh, and install the completion files as needed.
If you'd like to choose manually, you may set `WITH_ALLCOMP`,
`WITH_BASHCOMP`, or `WITH_ZSHCOMP` to `yes` or `no`. The exact
paths of the completions can be controlled with `BASHCOMPDIR`
and `ZSHCOMPDIR`.
