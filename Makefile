PREFIX     ?= /usr/local
BINDIR     ?= $(PREFIX)/bin
DATADIR    ?= $(PREFIX)/share
SYSCONFDIR ?= /etc
SYSTEMDUNITDIR ?= $(SYSCONFDIR)/systemd/system
DESTDIR    ?=

SUBST = sed 's|@BIN@|$(BINDIR)/acer|g'

.PHONY: all test install install-systemd install-openrc uninstall

all:

test:
	shellcheck acer tests/run.sh completions/acer.bash
	tests/run.sh

install:
	install -Dm755 acer                 $(DESTDIR)$(BINDIR)/acer
	install -Dm644 completions/acer.bash $(DESTDIR)$(DATADIR)/bash-completion/completions/acer
	install -Dm644 README.md            $(DESTDIR)$(DATADIR)/doc/acer-sense-cli/README.md
	install -Dm644 LICENSE              $(DESTDIR)$(DATADIR)/licenses/acer-sense-cli/LICENSE

# Optional: restore settings at boot and save them at shutdown.
install-systemd:
	install -d $(DESTDIR)$(SYSTEMDUNITDIR)
	$(SUBST) packaging/systemd/acer-sense.service > $(DESTDIR)$(SYSTEMDUNITDIR)/acer-sense.service
	chmod 644 $(DESTDIR)$(SYSTEMDUNITDIR)/acer-sense.service

install-openrc:
	install -d $(DESTDIR)$(SYSCONFDIR)/init.d
	$(SUBST) packaging/openrc/acer-sense > $(DESTDIR)$(SYSCONFDIR)/init.d/acer-sense
	chmod 755 $(DESTDIR)$(SYSCONFDIR)/init.d/acer-sense

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/acer
	rm -f $(DESTDIR)$(DATADIR)/bash-completion/completions/acer
	rm -rf $(DESTDIR)$(DATADIR)/doc/acer-sense-cli $(DESTDIR)$(DATADIR)/licenses/acer-sense-cli
	rm -f $(DESTDIR)$(SYSTEMDUNITDIR)/acer-sense.service
	rm -f $(DESTDIR)$(SYSCONFDIR)/init.d/acer-sense
