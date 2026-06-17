.PHONY: all romfs clean

# AdGuard Home - pre-built binary cho MIPS Little Endian (MT7621)
AGH_VERSION=0.107.55
AGH_BINARY=AdGuardHome_linux_mipsle_softfloat
AGH_URL=https://github.com/AdguardTeam/AdGuardHome/releases/download/v$(AGH_VERSION)/$(AGH_BINARY).tar.gz
AGH_SRC=AdGuardHome

THISDIR=$(shell pwd)

all: download_test extract_test

download_test:
	@( if [ ! -f $(THISDIR)/$(AGH_BINARY).tar.gz ]; then \
		echo "Downloading AdGuard Home v$(AGH_VERSION) for mipsle..."; \
		wget -t5 --timeout=60 --no-check-certificate \
			-O $(AGH_BINARY).tar.gz \
			$(AGH_URL); \
	fi )

extract_test:
	@( if [ ! -f $(THISDIR)/$(AGH_SRC)/AdGuardHome ]; then \
		echo "Extracting AdGuard Home..."; \
		tar xzf $(AGH_BINARY).tar.gz; \
	fi )

romfs:
	@echo "Installing AdGuard Home to romfs..."
	$(ROMFSINST) -e CONFIG_FIRMWARE_INCLUDE_ADGUARDHOME \
		$(THISDIR)/$(AGH_SRC)/AdGuardHome /usr/bin/AdGuardHome
	$(ROMFSINST) -e CONFIG_FIRMWARE_INCLUDE_ADGUARDHOME \
		adguardhome.sh /usr/bin/adguardhome.sh
	$(ROMFSINST) -e CONFIG_FIRMWARE_INCLUDE_ADGUARDHOME \
		-a "+x" /usr/bin/adguardhome.sh
	$(ROMFSINST) -e CONFIG_FIRMWARE_INCLUDE_ADGUARDHOME \
		-a "+x" /usr/bin/AdGuardHome
clean:
	rm -f $(AGH_BINARY).tar.gz
	rm -rf $(AGH_SRC)
