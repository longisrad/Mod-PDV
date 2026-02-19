# https://www.zlib.net

SRC_NAME = zlib-1.3.2
SRC_URL  = https://www.zlib.net/$(SRC_NAME).tar.xz

all: download_test extract_test config_test
	$(MAKE) -j$(HOST_NCPU) -C $(SRC_NAME)/build

download_test:
	( if [ ! -f $(SRC_NAME).tar.xz ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_NAME).tar.xz $(SRC_URL) \
			|| rm -f $(SRC_NAME).tar.xz; \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar xJf $(SRC_NAME).tar.xz; \
		cat patches/*.patch | patch -d $(SRC_NAME) -r - -N -p1; \
	fi )

config_test:
	( if [ -f ./config_done ]; then \
		echo "the same configuration"; \
	else \
		make configure && touch config_done; \
	fi )

configure:
	( mkdir -p $(SRC_NAME)/build && cd $(SRC_NAME)/build ; \
	cmake -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/ \
	-DCMAKE_TOOLCHAIN_FILE=$(ROOTDIR)/include/cross-mipsel-linux.cmake .. \
	)

clean:
	if [ -d $(SRC_NAME) ]; then \
		rm -rf $(SRC_NAME)/build; \
	fi; \
	rm -f config_done

install:
	$(MAKE) -C $(SRC_NAME)/build install DESTDIR="$(STAGEDIR)"

romfs:
	cp -fP $(DESTDIR)/lib/libz.so* $(ROMFSDIR)/lib
