SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:

DIRS = samples/ublox-test samples/area-tool samples/cliterm samples/muploader fc-cli mwp bbox-replay qproxy samples
INSTALLDIRS = $(DIRS:%=install-%)
LOCALDIRS = $(DIRS:%=local-%)
CLEANDIRS = $(DIRS:%=clean-%)

all: $(DIRS)
$(DIRS):
	$(MAKE) -C $@

sysinstall: install

install: $(INSTALLDIRS)
$(INSTALLDIRS):
	$(MAKE) -C $(@:install-%=%) install

local: $(LOCALDIRS)
$(LOCALDIRS):
	$(MAKE) -C $(@:local-%=%) local
	@cat docs/warn-local.txt

clean: $(CLEANDIRS)
$(CLEANDIRS):
	$(MAKE) -C $(@:clean-%=%) clean

.PHONY: subdirs $(DIRS)
.PHONY: subdirs $(BUILDDIRS)
.PHONY: subdirs $(INSTALLDIRS)
.PHONY: subdirs $(SYSINSTALLDIRS)
.PHONY: subdirs $(TESTDIRS)
.PHONY: subdirs $(CLEANDIRS)
.PHONY: all install clean local sysinstall
