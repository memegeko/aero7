#include "installercontroller.h"

#include <QtTest>

class InstallerControllerTest final : public QObject
{
    Q_OBJECT

private slots:
    void completesFullSimulationFlow()
    {
        InstallerController controller(false, true, QStringLiteral("/unused/backend"));

        QCOMPARE(controller.screenId(), QStringLiteral("LanguageScreen"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("WelcomeScreen"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("StartingScreen"));
        QTRY_COMPARE_WITH_TIMEOUT(controller.screenId(), QStringLiteral("LicenseScreen"), 3000);

        controller.setProperty("licenseAccepted", true);
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("InstallTypeScreen"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("DiskScreen"));
        controller.selectDisk(0);
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("ConfirmScreen"));

        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("ProgressScreen"));
        QTRY_COMPARE_WITH_TIMEOUT(controller.screenId(), QStringLiteral("CompleteScreen"), 8000);
        QCOMPARE(controller.restartSeconds(), 10);

        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("ApplyingSettingsScreen"));
        QVERIFY(controller.oobeMode());
        QTRY_COMPARE_WITH_TIMEOUT(controller.screenId(), QStringLiteral("VideoPerformanceScreen"), 3500);
        QTRY_COMPARE_WITH_TIMEOUT(controller.screenId(), QStringLiteral("AccountScreen"), 4000);

        controller.setProperty("username", QStringLiteral("geko"));
        controller.setProperty("computerName", QStringLiteral("aero7-pc"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("PasswordScreen"));
        controller.setProperty("password", QStringLiteral("correct-horse"));
        controller.setProperty("passwordConfirmation", QStringLiteral("correct-horse"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("UpdatesScreen"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("TimeScreen"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("NetworkScreen"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("FinalizingScreen"));

        QTRY_COMPARE_WITH_TIMEOUT(controller.screenId(), QStringLiteral("OobeWelcomeScreen"), 8000);
        QTRY_COMPARE_WITH_TIMEOUT(controller.screenId(), QStringLiteral("PreparingDesktopScreen"), 3500);
        QTRY_COMPARE_WITH_TIMEOUT(controller.screenId(), QStringLiteral("DesktopScreen"), 4000);
        QCOMPARE(controller.progress(), 100);

        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("LanguageScreen"));
        QVERIFY(!controller.oobeMode());
    }

    void rejectsInvalidAccountAndPassword()
    {
        InstallerController controller(true, true, QStringLiteral("/unused/backend"));
        QVERIFY(controller.jumpToForTest(QStringLiteral("AccountScreen")));
        controller.setProperty("username", QStringLiteral("Upper Case"));
        controller.setProperty("computerName", QStringLiteral("-invalid"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("AccountScreen"));
        QVERIFY(!controller.statusText().isEmpty());

        controller.setProperty("username", QStringLiteral("valid_user"));
        controller.setProperty("computerName", QStringLiteral("aero7-pc"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("PasswordScreen"));
        controller.setProperty("password", QStringLiteral("bad:password"));
        controller.setProperty("passwordConfirmation", QStringLiteral("bad:password"));
        controller.goNext();
        QCOMPARE(controller.screenId(), QStringLiteral("PasswordScreen"));
        QVERIFY(controller.statusText().contains(QLatin1Char(':')));
    }

    void recoveryShellIsSafeInSimulation()
    {
        InstallerController controller(false, true, QStringLiteral("/unused/backend"));
        controller.openRecoveryShell();
        QVERIFY(controller.statusText().contains(QStringLiteral("TTY2")));
        QCOMPARE(controller.screenId(), QStringLiteral("LanguageScreen"));
    }
};

QTEST_GUILESS_MAIN(InstallerControllerTest)
#include "test_installercontroller.moc"
