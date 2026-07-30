cmake_minimum_required(VERSION 3.24)
project(aero7-installer VERSION 0.1.0 LANGUAGES CXX)

include(CTest)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Test)

add_library(aero7-flow STATIC
    src/flowstate.cpp
    src/flowstate.h
)
target_link_libraries(aero7-flow PUBLIC Qt6::Core)
target_include_directories(aero7-flow PUBLIC src)

qt_add_executable(aero7-installer
    src/main.cpp
    src/installercontroller.cpp
    src/installercontroller.h
)
target_link_libraries(aero7-installer PRIVATE
    aero7-flow
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

set(AERO7_QML_FILES
    qml/Main.qml
    qml/components/AeroButton.qml
    qml/components/AeroCheckBox.qml
    qml/components/AeroChoice.qml
    qml/components/AeroComboBox.qml
    qml/components/AeroProgressBar.qml
    qml/components/AeroSpinner.qml
    qml/components/AeroTextField.qml
    qml/components/AnalogClock.qml
    qml/components/Brand.qml
    qml/components/CaptionButton.qml
    qml/components/GlassWindow.qml
    qml/components/ProgressFooter.qml
    qml/components/SetupPage.qml
    qml/screens/AccountScreen.qml
    qml/screens/ApplyingSettingsScreen.qml
    qml/screens/CompleteScreen.qml
    qml/screens/ConfirmScreen.qml
    qml/screens/DiskScreen.qml
    qml/screens/DesktopScreen.qml
    qml/screens/FinalizingScreen.qml
    qml/screens/InstallTypeScreen.qml
    qml/screens/LanguageScreen.qml
    qml/screens/LicenseScreen.qml
    qml/screens/NetworkScreen.qml
    qml/screens/OobeWelcomeScreen.qml
    qml/screens/PasswordScreen.qml
    qml/screens/PreparingDesktopScreen.qml
    qml/screens/ProgressScreen.qml
    qml/screens/StartingScreen.qml
    qml/screens/TimeScreen.qml
    qml/screens/UpdatesScreen.qml
    qml/screens/VideoPerformanceScreen.qml
    qml/screens/WelcomeScreen.qml
)

qt_add_resources(aero7-installer "qml_resources"
    PREFIX "/qml"
    BASE qml
    FILES ${AERO7_QML_FILES}
)
qt_add_resources(aero7-installer "art_resources"
    PREFIX "/assets"
    BASE assets
    FILES
        assets/aero7-background.png
        assets/aero7-logo-circle.png
        assets/aero7-logo-plain.png
        assets/aero7-mark.png
        assets/aero7-mark.svg
        assets/aero-shell/aero7-user.png
        assets/aero-shell/aero_bg_1.png
        assets/cursors/aero-pointer.svg
        assets/fonts/AdwaitaSans-Regular.ttf
        assets/icons/harddisk.svg
        assets/icons/install-clean.svg
        assets/icons/install-alongside.svg
        assets/icons/install-manual.svg
        assets/icons/shield-recommended.svg
        assets/icons/shield-notify.svg
        assets/icons/shield-manual.svg
        assets/icons/network-home.svg
        assets/icons/network-work.svg
        assets/icons/network-public.svg
        assets/icons/warning.svg
        assets/icons/refresh.svg
        assets/icons/check-green.svg
        assets/icons/recycle-bin.svg
        assets/loading/spinner_0.png
        assets/loading/spinner_1.png
        assets/loading/spinner_2.png
        assets/loading/spinner_3.png
        assets/loading/spinner_4.png
        assets/loading/spinner_5.png
        assets/loading/spinner_6.png
        assets/loading/spinner_7.png
        assets/loading/spinner_8.png
        assets/loading/spinner_9.png
        assets/loading/spinner_10.png
        assets/loading/spinner_11.png
        assets/loading/spinner_12.png
        assets/loading/spinner_13.png
        assets/loading/spinner_14.png
        assets/loading/spinner_15.png
        assets/loading/spinner_16.png
        assets/loading/spinner_17.png
        assets/controls/button-focused.png
        assets/controls/button-normal.png
        assets/controls/button-pressed.png
        assets/smod/back.png
        assets/smod/bottom.png
        assets/smod/close-active-glyph.png
        assets/smod/close-active.png
        assets/smod/close-glyph.png
        assets/smod/close-hover-glyph.png
        assets/smod/close-hover.png
        assets/smod/close.png
        assets/smod/left.png
        assets/smod/maximize-active-glyph.png
        assets/smod/maximize-active.png
        assets/smod/maximize-glyph.png
        assets/smod/maximize-hover-glyph.png
        assets/smod/maximize-hover.png
        assets/smod/maximize.png
        assets/smod/minimize-active-glyph.png
        assets/smod/minimize-active.png
        assets/smod/minimize-glyph.png
        assets/smod/minimize-hover-glyph.png
        assets/smod/minimize-hover.png
        assets/smod/minimize.png
        assets/smod/reflection.png
        assets/smod/right.png
        assets/smod/shadow.png
        assets/smod/top.png
)

install(TARGETS aero7-installer RUNTIME DESTINATION bin)

if(BUILD_TESTING)
    qt_add_executable(test-flowstate ../tests/test_flowstate.cpp)
    target_link_libraries(test-flowstate PRIVATE aero7-flow Qt6::Core Qt6::Test)
    add_test(NAME flowstate COMMAND test-flowstate)

    qt_add_executable(test-installercontroller
        ../tests/test_installercontroller.cpp
        src/installercontroller.cpp
        src/installercontroller.h
    )
    target_link_libraries(test-installercontroller PRIVATE aero7-flow Qt6::Core Qt6::Test)
    add_test(NAME installercontroller COMMAND test-installercontroller)
endif()
