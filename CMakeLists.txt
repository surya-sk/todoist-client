cmake_minimum_required(VERSION 3.25)
project(TodoistClient VERSION 0.1.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2)
find_package(KF6 6.0 REQUIRED COMPONENTS CoreAddons I18n Notifications Wallet WindowSystem)
find_package(KF6Kirigami 6.0 REQUIRED)
find_package(KF6KirigamiAddons 1.0 REQUIRED)

qt_standard_project_setup(REQUIRES 6.8)
add_subdirectory(src)
