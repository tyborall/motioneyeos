#############################################################
#
# motioneye
#
#############################################################

MOTIONEYEOS_VERSION = 20151101
MOTIONEYE_VERSION = 99ca42bb03448b6af15c1354b008278b5e316427
MOTIONEYE_SITE = $(call github,ccrisan,motioneye,$(MOTIONEYE_VERSION))
MOTIONEYE_SOURCE = $(MOTIONEYE_VERSION).tar.gz
MOTIONEYE_LICENSE = GPLv3
MOTIONEYE_LICENSE_FILES = LICENCE
MOTIONEYE_INSTALL_TARGET = YES
MOTIONEYE_SETUP_TYPE = setuptools

DST_DIR = $(TARGET_DIR)/usr/lib/python2.7/site-packages/motioneye
SHARE_DIR = $(TARGET_DIR)/usr/share/motioneye
BOARD = $(shell basename $(BASE_DIR))
BOARD_DIR = $(BASE_DIR)/../../board/$(BOARD)


define MOTIONEYE_INSTALL_TARGET_CMDS
    # setuptools install
    (cd $($(PKG)_BUILDDIR)/; \
        $($(PKG)_BASE_ENV) $($(PKG)_ENV) \
        $($(PKG)_PYTHON_INTERPRETER) setup.py install \
        $($(PKG)_BASE_INSTALL_TARGET_OPTS) \
        $($(PKG)_INSTALL_TARGET_OPTS))

    # additional config modules
    cp package/motioneye/update.py $(DST_DIR)
    cp package/motioneye/ipctl.py $(DST_DIR)
    cp package/motioneye/servicectl.py $(DST_DIR)
    cp package/motioneye/watchctl.py $(DST_DIR)
    cp package/motioneye/extractl.py $(DST_DIR)
    test -d $(BOARD_DIR)/motioneye-modules && cp $(BOARD_DIR)/motioneye-modules/*.py $(DST_DIR) || true
    grep servicectl $(DST_DIR)/config.py &>/dev/null || echo -e '\nimport ipctl\nimport servicectl\nimport watchctl\nimport extractl\ntry:\n    import boardctl\nexcept ImportError:\n    pass' >> $(DST_DIR)/config.py
    
    # log files
    if ! grep 'motioneye.log' $(DST_DIR)/handlers.py &>/dev/null; then \
        lineno=$$(grep -n -m1 LOGS $(DST_DIR)/handlers.py | cut -d ':' -f 1); \
        head -n $$(($$lineno + 1)) $(DST_DIR)/handlers.py > /tmp/handlers.py.new; \
        echo "        'motioneye': ('/var/log/motioneye.log', 'motioneye.log')," >> /tmp/handlers.py.new; \
        echo "        'messages': ('/var/log/messages', 'messages.log')," >> /tmp/handlers.py.new; \
        echo "        'boot': ('/var/log/boot.log', 'boot.log')," >> /tmp/handlers.py.new; \
        echo "        'dmesg': ('dmesg', 'dmesg.log')," >> /tmp/handlers.py.new; \
        tail -n +$$(($$lineno + 2)) $(DST_DIR)/handlers.py >> /tmp/handlers.py.new; \
        mv /tmp/handlers.py.new $(DST_DIR)/handlers.py; \
    fi

    # version & update
    sed -r -i "s%VERSION = .*%VERSION = '$(MOTIONEYEOS_VERSION)'%" $(DST_DIR)/__init__.py
    sed -r -i "s%enable_update=False%enable_update=True%" $(DST_DIR)/handlers.py
    
    # (re)compile all python modules
    $($(PKG)_PYTHON_INTERPRETER) -m compileall -d /usr/lib/python2.7/site-packages/motioneye -f $(DST_DIR)

    # meyectl
    echo -e '#!/bin/bash\n/usr/bin/python /usr/lib/python2.7/site-packages/motioneye/meyectl.pyc "$$@"' > $(TARGET_DIR)/usr/bin/meyectl
    chmod +x $(TARGET_DIR)/usr/bin/meyectl

    # cleanups
    rm -rf $(SHARE_DIR)/extra
endef

$(eval $(python-package))

