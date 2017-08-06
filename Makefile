PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
MANDIR ?= $(PREFIX)/share/man

PLATFORMFILE := src/platform/$(shell uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]').sh

BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions
ZSHCOMPDIR ?= $(PREFIX)/share/zsh/site-functions
FISHCOMPDIR ?= $(PREFIX)/share/fish/vendor_completions.d

ifneq ($(WITH_ALLCOMP),)
WITH_BASHCOMP := $(WITH_ALLCOMP)
WITH_ZSHCOMP := $(WITH_ALLCOMP)
WITH_FISHCOMP := $(WITH_ALLCOMP)
endif
ifeq ($(WITH_BASHCOMP),)
ifneq ($(strip $(wildcard $(BASHCOMPDIR))),)
WITH_BASHCOMP := yes
endif
endif
ifeq ($(WITH_ZSHCOMP),)
ifneq ($(strip $(wildcard $(ZSHCOMPDIR))),)
WITH_ZSHCOMP := yes
endif
endif

all:
	@echo "Note store is a shell script, so there is nothing to do. Try \"make install\" instead."

install-common:
	@install -v -d "$(DESTDIR)$(MANDIR)/man1" && install -m 0644 -v man/notes.1 "$(DESTDIR)$(MANDIR)/man1/notes.1"
	@[ "$(WITH_BASHCOMP)" = "yes" ] || exit 0; install -v -d "$(DESTDIR)$(BASHCOMPDIR)" && install -m 0644 -v src/completion/notes.bash-completion "$(DESTDIR)$(BASHCOMPDIR)/notes"
	@[ "$(WITH_ZSHCOMP)" = "yes" ] || exit 0; install -v -d "$(DESTDIR)$(ZSHCOMPDIR)" && install -m 0644 -v src/completion/notes.zsh-completion "$(DESTDIR)$(ZSHCOMPDIR)/_notes"


ifneq ($(strip $(wildcard $(PLATFORMFILE))),)
install: install-common
	@install -v -d "$(DESTDIR)$(LIBDIR)/note-store" && install -m 0644 -v "$(PLATFORMFILE)" "$(DESTDIR)$(LIBDIR)/note-store/platform.sh"
	@install -v -d "$(DESTDIR)$(LIBDIR)/note-store/extensions"
	@install -v -d "$(DESTDIR)$(BINDIR)/"
	@trap 'rm -f src/.notes' EXIT; sed 's:.*PLATFORM_FUNCTION_FILE.*:source "$(LIBDIR)/note-store/platform.sh":;s:^SYSTEM_EXTENSION_DIR=.*:SYSTEM_EXTENSION_DIR="$(LIBDIR)/note-store/extensions":' src/note-store.sh > src/.notes && \
	install -v -d "$(DESTDIR)$(BINDIR)/" && install -m 0755 -v src/.notes "$(DESTDIR)$(BINDIR)/notes"
else
install: install-common
	@install -v -d "$(DESTDIR)$(LIBDIR)/note-store/extensions"
	@trap 'rm -f src/.notes' EXIT; sed '/PLATFORM_FUNCTION_FILE/d;s:^SYSTEM_EXTENSION_DIR=.*:SYSTEM_EXTENSION_DIR="$(LIBDIR)/note-store/extensions":' src/note-store.sh > src/.notes && \
	install -v -d "$(DESTDIR)$(BINDIR)/" && install -m 0755 -v src/.notes "$(DESTDIR)$(BINDIR)/notes"
endif

uninstall:
	@rm -vrf \
		"$(DESTDIR)$(BINDIR)/notes" \
		"$(DESTDIR)$(LIBDIR)/note-store" \
		"$(DESTDIR)$(MANDIR)/man1/notes.1" \
		"$(DESTDIR)$(BASHCOMPDIR)/notes" \
		"$(DESTDIR)$(ZSHCOMPDIR)/_notes" \
		"$(DESTDIR)$(FISHCOMPDIR)/notes.fish"

TESTS = $(sort $(wildcard tests/t[0-9][0-9][0-9][0-9]-*.sh))

test: $(TESTS)

$(TESTS):
	@$@ $(NOTES_TEST_OPTS)

clean:
	$(RM) -rf tests/test-results/ tests/trash\ directory.*/ tests/gnupg/random_seed

.PHONY: install uninstall install-common test clean $(TESTS)
