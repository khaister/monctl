bindir ?= /usr/local/bin

# Compiler flags:
#  -Wall turns on most but not all compiler warnings
#  -Wno-deprecated-declarations is used because CGDisplayIOServicePort was
#    deprecated by Apple with no replacement
#    https://developer.apple.com/documentation/coregraphics/1543516-cgdisplayioserviceport
WARNINGS := -Wno-deprecated-declarations
WARNINGS += -Wall
WARNINGS += -Wempty-body
WARNINGS += -Wempty-init-stmt
WARNINGS += -Wignored-qualifiers
WARNINGS += -Winitializer-overrides
WARNINGS += -Wmissing-field-initializers
WARNINGS += -Wmissing-method-return-type
WARNINGS += -Wnull-pointer-arithmetic
WARNINGS += -Woverride-init
WARNINGS += -Wredundant-move
WARNINGS += -Wsemicolon-before-method-body
WARNINGS += -Wshift-negative-value
WARNINGS += -Wstring-compare
WARNINGS += -Wtype-limits
WARNINGS += -Wuninitialized
WARNINGS += -Wunused-parameter
WARNINGS += -Wbitfield-enum-conversion
WARNINGS += -Wbool-conversion
WARNINGS += -Wconstant-conversion
WARNINGS += -Wenum-conversion
WARNINGS += -Wimplicit-float-conversion
WARNINGS += -Wimplicit-int-conversion
WARNINGS += -Wint-conversion
WARNINGS += -Wliteral-conversion
WARNINGS += -Wnon-literal-null-conversion
WARNINGS += -Wnull-conversion
WARNINGS += -Wobjc-literal-conversion
WARNINGS += -Wshorten-64-to-32
WARNINGS += -Wstring-conversion
WARNINGS += -Wshadow-field
WARNINGS += -Wshadow-field-in-constructor
WARNINGS += -Wshadow-uncaptured-local
WARNINGS += -Wformat
WARNINGS += -Wlogical-not-parentheses
WARNINGS += -Wnull-dereference
#WARNINGS += -Wextra #TODO enable after fixing these warnings

INSTALL ?= install
INSTALL_PROGRAM ?= $(INSTALL)
INSTALL_DATA ?= $(INSTALL) -m 644

.PHONY: all
all: displayplacer

displayplacer:
	$(CC) -I. $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) DisplayPlacer.c Legacy/v130.c -x objective-c MonitorPanel.m -o $@ $< -F./Headers -F/System/Library/PrivateFrameworks -framework IOKit -framework ApplicationServices -framework DisplayServices -framework CoreDisplay -framework OSD -framework MonitorPanel -framework SkyLight $(WARNINGS)

.PHONY: debug
debug: CFLAGS += -g
debug: displayplacer

.PHONY: install
install: displayplacer
	$(INSTALL_PROGRAM) $< $(DESTDIR)$(bindir)

# Hardware-independent C unit tests (mode selection logic). Deliberately does not
# link MonitorPanel.m or any private framework, so it builds and runs anywhere.
.PHONY: test
test: ../tests/unit/test_mode_selection
	../tests/unit/test_mode_selection

../tests/unit/test_mode_selection: ../tests/unit/test_mode_selection.c Header.h
	$(CC) -I. $< -o $@ -framework IOKit -framework ApplicationServices

.PHONY: clean
clean:
	rm -f displayplacer
	rm -f ../tests/unit/test_mode_selection
