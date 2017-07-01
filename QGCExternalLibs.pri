#
# [REQUIRED] Add support for <inttypes.h> to Windows.
#
WindowsBuild {
    INCLUDEPATH += libs/lib/msinttypes
}

#
# [REQUIRED] Add support for the MAVLink communications protocol.
# Mavlink dialect is hardwired to arudpilotmega for now. The reason being
# the current codebase supports both PX4 and APM flight stack. PX4 flight stack
# only usese common mavlink specifications, whereas APM flight stack uses custom
# mavlink specifications which add to common. So by using the adupilotmega dialect
# QGC can support both in the same codebase.
#
# Once the mavlink helper routines include support for multiple dialects within
# a single compiled codebase this hardwiring of dialect can go away. But until then
# this "workaround" is needed.

MAVLINKPATH_REL = libs/mavlink/include/mavlink/v2.0
MAVLINKPATH = $$BASEDIR/$$MAVLINKPATH_REL
MAVLINK_CONF = ASLUAV
DEFINES += MAVLINK_NO_DATA

# First we select the dialect, checking for valid user selection
# Users can override all other settings by specifying MAVLINK_CONF as an argument to qmake
!isEmpty(MAVLINK_CONF) {
    message($$sprintf("Using MAVLink dialect '%1'.", $$MAVLINK_CONF))
}

# Then we add the proper include paths dependent on the dialect.
INCLUDEPATH += $$MAVLINKPATH

exists($$MAVLINKPATH/common) {
    !isEmpty(MAVLINK_CONF) {
        count(MAVLINK_CONF, 1) {
            exists($$MAVLINKPATH/$$MAVLINK_CONF) {
                INCLUDEPATH += $$MAVLINKPATH/$$MAVLINK_CONF
                DEFINES += $$sprintf('QGC_USE_%1_MESSAGES', $$upper($$MAVLINK_CONF))
            } else {
                error($$sprintf("MAVLink dialect '%1' does not exist at '%2'!", $$MAVLINK_CONF, $$MAVLINKPATH_REL))
            }
        } else {
            error(Only a single mavlink dialect can be specified in MAVLINK_CONF)
        }
    } else {
        INCLUDEPATH += $$MAVLINKPATH/common
    }
} else {
    error($$sprintf("MAVLink folder does not exist at '%1'! Run 'git submodule init && git submodule update' on the command line.",$$MAVLINKPATH_REL))
}

#
# [REQUIRED] EIGEN matrix library
# NOMINMAX constant required to make internal min/max work.
INCLUDEPATH += libs/eigen
DEFINES += NOMINMAX

#
# [REQUIRED] QWT plotting library dependency. Provides plotting capabilities.
#
!MobileBuild {
include(libs/qwt.pri)
DEPENDPATH += libs/qwt
INCLUDEPATH += libs/qwt
}

#
# [REQUIRED] SDL dependency. Provides joystick/gamepad support.
# The SDL is packaged with QGC for the Mac and Windows. Linux support requires installing the SDL
# library (development libraries and static binaries).
#
MacBuild {
    INCLUDEPATH += \
        $$BASEDIR/libs/lib/Frameworks/SDL2.framework/Headers

    LIBS += \
        -F$$BASEDIR/libs/lib/Frameworks \
        -framework SDL2
} else:LinuxBuild {
    PKGCONFIG = sdl2
} else:WindowsBuild {
    INCLUDEPATH += $$BASEDIR/libs/lib/sdl2/msvc/include

    contains(QT_ARCH, i386) {
        LIBS += -L$$BASEDIR/libs/lib/sdl2/msvc/lib/x86
    } else {
        LIBS += -L$$BASEDIR/libs/lib/sdl2/msvc/lib/x64
    }
    LIBS += \
        -lSDL2main \
        -lSDL2
}

##
# [OPTIONAL] Speech synthesis library support.
# Can be forcibly disabled by adding a `DEFINES+=DISABLE_SPEECH` argument to qmake.
# Linux support requires the eSpeak speech synthesizer (espeak).
# Mac support is provided in Snow Leopard and newer (10.6+)
# Windows is supported as of Windows 7
#
contains (DEFINES, DISABLE_SPEECH) {
    message("Skipping support for speech output (manual override from command line)")
    DEFINES -= DISABLE_SPEECH
# Otherwise the user can still disable this feature in the user_config.pri file.
} else:exists(user_config.pri):infile(user_config.pri, DEFINES, DISABLE_SPEECH) {
    message("Skipping support for speech output (manual override from user_config.pri)")
} else:LinuxBuild {
    exists(/usr/include/espeak) | exists(/usr/local/include/espeak) {
        message("Including support for speech output")
        DEFINES += QGC_SPEECH_ENABLED
        LIBS += \
        -lespeak
    } else {
        warning("Skipping support for speech output (missing libraries, see README)")
    }
}
# Mac support is built into OS 10.6+.
else:MacBuild|iOSBuild {
    message("Including support for speech output")
    DEFINES += QGC_SPEECH_ENABLED
}
# Windows supports speech through native API.
else:WindowsBuild {
    message("Including support for speech output")
    DEFINES += QGC_SPEECH_ENABLED
    LIBS    += -lOle32
}
# Android supports speech through native (Java) API.
else:AndroidBuild {
    message("Including support for speech output")
    DEFINES += QGC_SPEECH_ENABLED
    QMAKE_CXXFLAGS += -g
    INCLUDEPATH += \
        libs/breakpad/src \
        libs/breakpad/src/common/android/include
    HEADERS += \
        libs/breakpad/src/client/linux/crash_generation/crash_generation_client.h \
        libs/breakpad/src/client/linux/handler/exception_handler.h \
        libs/breakpad/src/client/linux/handler/minidump_descriptor.h \
        libs/breakpad/src/client/linux/log/log.h \
        libs/breakpad/src/client/linux/dump_writer_common/thread_info.h \
        libs/breakpad/src/client/linux/dump_writer_common/ucontext_reader.h \
        libs/breakpad/src/client/linux/microdump_writer/microdump_writer.h \
        libs/breakpad/src/client/linux/minidump_writer/cpu_set.h \
        libs/breakpad/src/client/linux/minidump_writer/proc_cpuinfo_reader.h \
        libs/breakpad/src/client/linux/minidump_writer/minidump_writer.h \
        libs/breakpad/src/client/linux/minidump_writer/line_reader.h \
        libs/breakpad/src/client/linux/minidump_writer/linux_dumper.h \
        libs/breakpad/src/client/linux/minidump_writer/linux_ptrace_dumper.h \
        libs/breakpad/src/client/linux/minidump_writer/directory_reader.h \
        libs/breakpad/src/client/minidump_file_writer-inl.h \
        libs/breakpad/src/client/minidump_file_writer.h \
        libs/breakpad/src/common/scoped_ptr.h \
        libs/breakpad/src/common/linux/linux_libc_support.h \
        libs/breakpad/src/common/linux/eintr_wrapper.h \
        libs/breakpad/src/common/linux/ignore_ret.h \
        libs/breakpad/src/common/linux/file_id.h \
        libs/breakpad/src/common/linux/memory_mapped_file.h \
        libs/breakpad/src/common/linux/safe_readlink.h \
        libs/breakpad/src/common/linux/guid_creator.h \
        libs/breakpad/src/common/linux/elfutils.h \
        libs/breakpad/src/common/linux/elfutils-inl.h \
        libs/breakpad/src/common/linux/elf_gnu_compat.h \
        libs/breakpad/src/common/using_std_string.h \
        libs/breakpad/src/common/memory.h \
        libs/breakpad/src/common/basictypes.h \
        libs/breakpad/src/common/memory_range.h \
        libs/breakpad/src/common/string_conversion.h \
        libs/breakpad/src/common/convert_UTF.h \
        libs/breakpad/src/google_breakpad/common/minidump_format.h \
        libs/breakpad/src/google_breakpad/common/minidump_size.h \
        libs/breakpad/src/google_breakpad/common/breakpad_types.h \
        libs/breakpad/src/third_party/lss/linux_syscall_support.h
    SOURCES += \
        libs/breakpad/src/client/linux/crash_generation/crash_generation_client.cc \
        libs/breakpad/src/client/linux/handler/exception_handler.cc \
        libs/breakpad/src/client/linux/handler/minidump_descriptor.cc \
        libs/breakpad/src/client/linux/dump_writer_common/thread_info.cc \
        libs/breakpad/src/client/linux/dump_writer_common/ucontext_reader.cc \
        libs/breakpad/src/client/linux/log/log.cc \
        libs/breakpad/src/client/linux/microdump_writer/microdump_writer.cc \
        libs/breakpad/src/client/linux/minidump_writer/minidump_writer.cc \
        libs/breakpad/src/client/linux/minidump_writer/linux_dumper.cc \
        libs/breakpad/src/client/linux/minidump_writer/linux_ptrace_dumper.cc \
        libs/breakpad/src/client/minidump_file_writer.cc \
        libs/breakpad/src/common/linux/linux_libc_support.cc \
        libs/breakpad/src/common/linux/file_id.cc \
        libs/breakpad/src/common/linux/memory_mapped_file.cc \
        libs/breakpad/src/common/linux/safe_readlink.cc \
        libs/breakpad/src/common/linux/guid_creator.cc \
        libs/breakpad/src/common/linux/elfutils.cc \
        libs/breakpad/src/common/string_conversion.cc \
        libs/breakpad/src/common/convert_UTF.c \
        libs/breakpad/src/common/android/breakpad_getcontext.S
}

#
# [OPTIONAL] Zeroconf for UDP links
#
contains (DEFINES, DISABLE_ZEROCONF) {
    message("Skipping support for Zeroconf (manual override from command line)")
    DEFINES -= DISABLE_ZEROCONF
# Otherwise the user can still disable this feature in the user_config.pri file.
} else:exists(user_config.pri):infile(user_config.pri, DEFINES, DISABLE_ZEROCONF) {
    message("Skipping support for Zeroconf (manual override from user_config.pri)")
# Mac support is built into OS
} else:MacBuild|iOSBuild {
    message("Including support for Zeroconf (Bonjour)")
    DEFINES += QGC_ZEROCONF_ENABLED
} else {
    message("Skipping support for Zeroconf (unsupported platform)")
}

