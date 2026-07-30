#include "flowstate.h"

#include <QtTest>

class FlowStateTest final : public QObject
{
    Q_OBJECT

private slots:
    void installerOrder()
    {
        FlowState flow(FlowState::Mode::Installer);
        QCOMPARE(flow.count(), 9);
        QCOMPARE(flow.screenId(), QStringLiteral("LanguageScreen"));
        QStringList visited{flow.screenId()};
        while (flow.next())
            visited << flow.screenId();
        QCOMPARE(visited,
                 QStringList({QStringLiteral("LanguageScreen"), QStringLiteral("WelcomeScreen"),
                              QStringLiteral("StartingScreen"), QStringLiteral("LicenseScreen"),
                              QStringLiteral("InstallTypeScreen"), QStringLiteral("DiskScreen"),
                              QStringLiteral("ConfirmScreen"), QStringLiteral("ProgressScreen"),
                              QStringLiteral("CompleteScreen")}));
        QVERIFY(!flow.next());
    }

    void oobeOrderAndBounds()
    {
        FlowState flow(FlowState::Mode::Oobe);
        QCOMPARE(flow.count(), 11);
        QCOMPARE(flow.screenId(), QStringLiteral("ApplyingSettingsScreen"));
        QVERIFY(!flow.back());
        QStringList visited{flow.screenId()};
        while (flow.next())
            visited << flow.screenId();
        QCOMPARE(visited,
                 QStringList({QStringLiteral("ApplyingSettingsScreen"),
                              QStringLiteral("VideoPerformanceScreen"),
                              QStringLiteral("AccountScreen"),
                              QStringLiteral("PasswordScreen"),
                              QStringLiteral("UpdatesScreen"),
                              QStringLiteral("TimeScreen"),
                              QStringLiteral("NetworkScreen"),
                              QStringLiteral("FinalizingScreen"),
                              QStringLiteral("OobeWelcomeScreen"),
                              QStringLiteral("PreparingDesktopScreen"),
                              QStringLiteral("DesktopScreen")}));
        QVERIFY(!flow.next());
        QVERIFY(!flow.jumpTo(QStringLiteral("ProductKeyScreen")));
    }

    void resetAndModeChange()
    {
        FlowState flow;
        QVERIFY(flow.next());
        flow.reset();
        QCOMPARE(flow.index(), 0);
        flow.setMode(FlowState::Mode::Oobe);
        QCOMPARE(flow.screenId(), QStringLiteral("ApplyingSettingsScreen"));
    }
};

QTEST_MAIN(FlowStateTest)
#include "test_flowstate.moc"
