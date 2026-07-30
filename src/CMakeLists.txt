qt_add_executable(todoistclient
    main.cpp
    notificationmetadata.cpp
    notificationmetadata.h
    credentialstore.cpp
    credentialstore.h
    todoistcontroller.cpp
    todoistcontroller.h
)

qt_add_resources(todoistclient "todoist_notification_metadata"
    PREFIX "/"
    FILES org.suryask.todoist.notifyrc
)

qt_add_qml_module(todoistclient
    URI TodoistClient
    VERSION 1.0
    QML_FILES qml/Main.qml
)

target_link_libraries(todoistclient PRIVATE
    Qt6::Core Qt6::Gui Qt6::Network Qt6::Qml Qt6::Quick Qt6::QuickControls2
    KF6::CoreAddons KF6::I18n KF6::I18nQml KF6::Kirigami
    KF6::Notifications KF6::Wallet KF6::WindowSystem
)

install(TARGETS todoistclient ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
configure_file(
    org.suryask.todoist.desktop.in
    ${CMAKE_CURRENT_BINARY_DIR}/org.suryask.todoist.desktop
    @ONLY
)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/org.suryask.todoist.desktop
    DESTINATION ${KDE_INSTALL_APPDIR}
)
install(FILES org.suryask.todoist.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})
install(FILES org.suryask.todoist.notifyrc DESTINATION ${KDE_INSTALL_DATADIR}/knotifications6)
