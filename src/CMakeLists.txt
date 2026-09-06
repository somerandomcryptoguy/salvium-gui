add_subdirectory(QR-Code-scanner)
add_subdirectory(openpgp)
add_subdirectory(zxcvbn-c)

qt5_add_resources(RESOURCES ../qml.qrc)

# Compile source files (.h/.cpp)
file(GLOB SOURCE_FILES
	"*.h"
	"*.cpp"
    "main/*.h"
    "main/*.cpp"
    "libwalletqt/WalletManager.cpp"
    "libwalletqt/WalletListenerImpl.cpp"
    "libwalletqt/Wallet.cpp"
    "libwalletqt/PassphraseHelper.cpp"
    "libwalletqt/YieldInfo.cpp"
    "libwalletqt/PendingTransaction.cpp"
    "libwalletqt/TransactionHistory.cpp"
    "libwalletqt/TransactionInfo.cpp"
    "libwalletqt/QRCodeImageProvider.cpp"
    "libwalletqt/AddressBook.cpp"
    "libwalletqt/Subaddress.cpp"
    "libwalletqt/SubaddressAccount.cpp"
    "libwalletqt/UnsignedTransaction.cpp"
    "libwalletqt/WalletManager.h"
    "libwalletqt/Wallet.h"
    "libwalletqt/PassphraseHelper.h"
    "libwalletqt/PendingTransaction.h"
    "libwalletqt/YieldInfo.h"
    "libwalletqt/TransactionHistory.h"
    "libwalletqt/TransactionInfo.h"
    "libwalletqt/QRCodeImageProvider.h"
    "libwalletqt/Transfer.h"
    "libwalletqt/AddressBook.h"
    "libwalletqt/Subaddress.h"
    "libwalletqt/SubaddressAccount.h"
    "libwalletqt/UnsignedTransaction.h"
    "daemon/*.h"
    "daemon/*.cpp"
    "p2pool/*.h"
    "p2pool/*.cpp"
    "model/*.h"
    "model/*.cpp"
    "qt/*.h"
    "qt/*.cpp"
)
if(APPLE)
    list(APPEND SOURCE_FILES "qt/macoshelper.mm")
endif()

set(EXECUTABLE_FLAG)
if(MINGW)
    set(EXECUTABLE_FLAG WIN32)

    set(ICON ${PROJECT_SOURCE_DIR}/images/appicon.ico)
    set(ICON_RC ${CMAKE_CURRENT_BINARY_DIR}/icon.rc)
    set(ICON_RES ${CMAKE_CURRENT_BINARY_DIR}/icon.o)
    file(WRITE ${ICON_RC} "IDI_ICON1 ICON DISCARDABLE \"${ICON}\"")
    find_program(Qt5_WINDRES_EXECUTABLE NAMES windres x86_64-w64-mingw32-windres REQUIRED CMAKE_FIND_ROOT_PATH_BOTH)
    add_custom_command(OUTPUT ${ICON_RES} COMMAND ${Qt5_WINDRES_EXECUTABLE} ${ICON_RC} ${ICON_RES} MAIN_DEPENDENCY ${ICON_RC})
    list(APPEND RESOURCES ${ICON_RES})
endif()

if(APPLE)
    set(ICON ${PROJECT_SOURCE_DIR}/images/appicon.icns)
    set_source_files_properties(${ICON} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    list(APPEND RESOURCES ${ICON})
endif()

set(monero_wallet_gui_sources
    ${SOURCE_FILES}
    ${RESOURCES}
)

if(NOT ANDROID)
    add_executable(salvium-wallet-gui ${EXECUTABLE_FLAG} ${monero_wallet_gui_sources})
else()
    add_library(salvium-wallet-gui SHARED ${monero_wallet_gui_sources})
    set_target_properties(salvium-wallet-gui PROPERTIES COMPILE_DEFINITIONS "ANDROID")
endif()

# A desktop GUI release is also a complete Salvium binary set. Keep these as
# explicit dependencies so building only the GUI target still refreshes every
# embedded-core executable whose inputs changed and recreates any one that is
# missing from the shared ${CMAKE_BINARY_DIR}/bin output directory.
if(NOT ANDROID)
    add_dependencies(salvium-wallet-gui
        wallet_rpc_server
        simplewallet
        gen_multisig
        gen_ssl_cert
        daemon
        blockchain_import
        blockchain_export
        blockchain_blackball
        blockchain_usage
        blockchain_ancestry
        blockchain_depth
        blockchain_scanner
        blockchain_verification
        blockchain_stats
        blockchain_prune_known_spent_data
        blockchain_prune)
endif()

set_target_properties(salvium-wallet-gui PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/share/Info.plist"
)

# OpenGL
target_include_directories(salvium-wallet-gui PUBLIC ${OPENGL_INCLUDE_DIR})
message(STATUS "OpenGL: include dir at ${OPENGL_INCLUDE_DIR}")
message(STATUS "OpenGL: libraries at ${OPENGL_LIBRARIES}")

target_include_directories(salvium-wallet-gui PUBLIC ${Qt5Gui_PRIVATE_INCLUDE_DIRS})

target_include_directories(salvium-wallet-gui PUBLIC
    ${CMAKE_SOURCE_DIR}/salvium/include
    ${CMAKE_SOURCE_DIR}/salvium/src
    ${CMAKE_SOURCE_DIR}/salvium/src/crypto
    ${CMAKE_SOURCE_DIR}/salvium/external/mx25519/include
    ${CMAKE_SOURCE_DIR}/salvium/external/easylogging++
    ${CMAKE_SOURCE_DIR}/salvium/contrib/epee/include
    ${CMAKE_SOURCE_DIR}/salvium/external/qrcodegen
	${CMAKE_CURRENT_SOURCE_DIR}
	${CMAKE_CURRENT_SOURCE_DIR}/daemon
    ${CMAKE_CURRENT_SOURCE_DIR}/p2pool
	${CMAKE_CURRENT_SOURCE_DIR}/libwalletqt
	${CMAKE_CURRENT_SOURCE_DIR}/model
	${CMAKE_CURRENT_SOURCE_DIR}/QR-Code-scanner
	${CMAKE_CURRENT_SOURCE_DIR}/zxcvbn-c
    ${X11_INCLUDE_DIR}
)

target_compile_definitions(salvium-wallet-gui
	PUBLIC
	${Qt5Widgets_DEFINITIONS}
    ${Qt5Qml_DEFINITIONS}
)

if(APPLE)
    if(NOT ICU_ROOT)
        execute_process(COMMAND brew --prefix icu4c OUTPUT_VARIABLE ICU_ROOT OUTPUT_STRIP_TRAILING_WHITESPACE)
    endif()
    find_package(ICU REQUIRED COMPONENTS data i18n uc)
    target_link_directories(salvium-wallet-gui PRIVATE ${ICU_ROOT}/lib)
    # ScreenCaptureKit for macOS 14+ screenshot capture (weak link for backward compat)
    target_link_libraries(salvium-wallet-gui "-weak_framework ScreenCaptureKit")
endif()

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${Qt5Widgets_EXECUTABLE_COMPILE_FLAGS}")

target_link_libraries(salvium-wallet-gui
    epee
    common
    net
    wallet_api
    qrcodegen
    easylogging
    ${QT5_LIBRARIES}
    ${EXTRA_LIBRARIES}
    openpgp
    qrdecoder
    translations
    zxcvbn
)

if(X11_FOUND)
    target_link_libraries(salvium-wallet-gui ${X11_LIBRARIES})
endif()

if(WITH_SCANNER)
    target_link_libraries(salvium-wallet-gui qrscanner)
    if(LINUX AND NOT ANDROID)
        target_link_libraries(salvium-wallet-gui
            jpeg
            v4l2
            v4lconvert
            rt
        )
    endif()
endif()

if(MINGW AND STATIC AND NOT DEPENDS)
    # MSYS2's static Boost.Locale is built against ICU's DLL ABI.  Deploy
    # that unavoidable runtime chain beside the otherwise-static executable.
    get_filename_component(MINGW_BIN_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)
    file(GLOB ICU_RUNTIME_DLLS
        "${MINGW_BIN_DIR}/libicudt*.dll"
        "${MINGW_BIN_DIR}/libicuin*.dll"
        "${MINGW_BIN_DIR}/libicuuc*.dll"
    )
    set(MINGW_RUNTIME_DLLS
        "${MINGW_BIN_DIR}/libgcc_s_seh-1.dll"
        "${MINGW_BIN_DIR}/libstdc++-6.dll"
        "${MINGW_BIN_DIR}/libwinpthread-1.dll"
    )
    if(NOT ICU_RUNTIME_DLLS)
        message(FATAL_ERROR "Static MinGW build requires ICU runtime DLLs in ${MINGW_BIN_DIR}")
    endif()
    foreach(RUNTIME_DLL IN LISTS MINGW_RUNTIME_DLLS)
        if(NOT EXISTS "${RUNTIME_DLL}")
            message(FATAL_ERROR "Static MinGW build requires ${RUNTIME_DLL}")
        endif()
    endforeach()
    set(WINDOWS_RUNTIME_DLLS ${ICU_RUNTIME_DLLS} ${MINGW_RUNTIME_DLLS})
    add_custom_command(TARGET salvium-wallet-gui POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${WINDOWS_RUNTIME_DLLS}
            $<TARGET_FILE_DIR:salvium-wallet-gui>
        COMMENT "Deploying ICU and MinGW runtime DLLs"
    )
endif()

include(Deploy)

install(TARGETS salvium-wallet-gui
    DESTINATION bin
)
