#pragma once

#include "flowstate.h"

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

class InstallerController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString screenId READ screenId NOTIFY screenChanged)
    Q_PROPERTY(bool oobeMode READ oobeMode NOTIFY oobeModeChanged)
    Q_PROPERTY(bool demoMode READ demoMode CONSTANT)
    Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY screenChanged)
    Q_PROPERTY(QVariantList disks READ disks NOTIFY disksChanged)
    Q_PROPERTY(QVariantMap selectedDisk READ selectedDisk NOTIFY selectedDiskChanged)
    Q_PROPERTY(bool diskSelectionReady READ diskSelectionReady NOTIFY selectedDiskChanged)
    Q_PROPERTY(bool advancedDriveOptions READ advancedDriveOptions NOTIFY advancedDriveOptionsChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(int progressStageIndex READ progressStageIndex NOTIFY progressChanged)
    Q_PROPERTY(int progressStagePercent READ progressStagePercent NOTIFY progressChanged)
    Q_PROPERTY(QString progressStage READ progressStage NOTIFY progressChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool setupFailed READ setupFailed NOTIFY setupFailureChanged)
    Q_PROPERTY(QString failureDetails READ failureDetails NOTIFY setupFailureChanged)
    Q_PROPERTY(int restartSeconds READ restartSeconds NOTIFY restartSecondsChanged)
    Q_PROPERTY(bool desktopHandoff READ desktopHandoff NOTIFY desktopHandoffChanged)

    Q_PROPERTY(QString language MEMBER m_language NOTIFY formChanged)
    Q_PROPERTY(QString timeFormat MEMBER m_timeFormat NOTIFY formChanged)
    Q_PROPERTY(QString keyboard MEMBER m_keyboard NOTIFY formChanged)
    Q_PROPERTY(bool licenseAccepted MEMBER m_licenseAccepted NOTIFY formChanged)
    Q_PROPERTY(QString installType MEMBER m_installType NOTIFY formChanged)
    Q_PROPERTY(QString username MEMBER m_username NOTIFY formChanged)
    Q_PROPERTY(QString computerName MEMBER m_computerName NOTIFY formChanged)
    Q_PROPERTY(QString password MEMBER m_password NOTIFY formChanged)
    Q_PROPERTY(QString passwordConfirmation MEMBER m_passwordConfirmation NOTIFY formChanged)
    Q_PROPERTY(QString passwordHint MEMBER m_passwordHint NOTIFY formChanged)
    Q_PROPERTY(QString updatePreference MEMBER m_updatePreference NOTIFY formChanged)
    Q_PROPERTY(QString timezone MEMBER m_timezone NOTIFY formChanged)
    Q_PROPERTY(QString networkChoice MEMBER m_networkChoice NOTIFY formChanged)

public:
    explicit InstallerController(bool oobeMode, bool demoMode, QString backendPath,
                                 QObject *parent = nullptr);

    [[nodiscard]] QString screenId() const;
    [[nodiscard]] bool oobeMode() const;
    [[nodiscard]] bool demoMode() const;
    [[nodiscard]] bool canGoBack() const;
    [[nodiscard]] QVariantList disks() const;
    [[nodiscard]] QVariantMap selectedDisk() const;
    [[nodiscard]] bool diskSelectionReady() const;
    [[nodiscard]] bool advancedDriveOptions() const;
    [[nodiscard]] int progress() const;
    [[nodiscard]] int progressStageIndex() const;
    [[nodiscard]] int progressStagePercent() const;
    [[nodiscard]] QString progressStage() const;
    [[nodiscard]] QString statusText() const;
    [[nodiscard]] bool busy() const;
    [[nodiscard]] bool setupFailed() const;
    [[nodiscard]] QString failureDetails() const;
    [[nodiscard]] int restartSeconds() const;
    [[nodiscard]] bool desktopHandoff() const;

    Q_INVOKABLE void goNext();
    Q_INVOKABLE void goBack();
    Q_INVOKABLE void selectDisk(int index);
    Q_INVOKABLE void refreshDisks();
    Q_INVOKABLE void setAdvancedDriveOptions(bool enabled);
    Q_INVOKABLE void useSelectedFreeSpace(int sizeGiB);
    Q_INVOKABLE void useSelectedPartition();
    Q_INVOKABLE void prepareSelectedNtfsShrink(int releaseGiB);
    Q_INVOKABLE void deleteSelectedPartition();
    Q_INVOKABLE void extendSelectedPartition(int amountGiB);
    Q_INVOKABLE void loadStorageDriver(const QUrl &source);
    Q_INVOKABLE void openRecoveryShell();
    Q_INVOKABLE void restartSystem();
    Q_INVOKABLE void resetDemo();
    Q_INVOKABLE bool jumpToForTest(const QString &screen);

signals:
    void screenChanged();
    void disksChanged();
    void selectedDiskChanged();
    void advancedDriveOptionsChanged();
    void progressChanged();
    void statusChanged();
    void busyChanged();
    void setupFailureChanged();
    void formChanged();
    void oobeModeChanged();
    void restartSecondsChanged();
    void desktopHandoffChanged();

private slots:
    void advanceTransition();
    void advanceDemoProgress();
    void readBackendOutput();
    void readBackendError();
    void backendFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void tickRestartCountdown();
    void handoffToDesktop();

private:
    void moveNext();
    void enterCurrentScreen();
    void enterOobeFlow();
    void continueAfterInstallation();
    void beginDesktopHandoff();
    void setStatus(const QString &text);
    void setBusy(bool busy);
    void clearSetupFailure();
    void startInstallation();
    void startOobeFinalization();
    void startDemoProgress(bool oobe);
    void startBackend(const QStringList &arguments, const QString &planPath,
                      const QString &purpose = QStringLiteral("install"));
    QString writeInstallPlan() const;
    QString writeStorageActionPlan(const QString &action, int amountGiB = 0) const;
    QString writeOobePlan() const;
    bool validateCurrentScreen();
    void handleBackendEvent(const QByteArray &line);

    FlowState m_flow;
    bool m_initialOobeMode = false;
    bool m_oobeMode = false;
    bool m_demoMode = true;
    QString m_backendPath;
    QVariantList m_disks;
    QVariantMap m_selectedDisk;
    int m_selectedDiskIndex = -1;
    bool m_advancedDriveOptions = false;
    int m_progress = 0;
    int m_progressStageIndex = 0;
    int m_progressStagePercent = 0;
    QString m_progressStage;
    QString m_statusText;
    bool m_busy = false;
    bool m_setupFailed = false;
    QString m_failureDetails;
    QTimer m_transitionTimer;
    QTimer m_progressTimer;
    QTimer m_restartTimer;
    QTimer m_desktopHandoffTimer;
    int m_restartSeconds = 10;
    bool m_desktopHandoff = false;
    QProcess m_backend;
    QByteArray m_backendBuffer;
    QByteArray m_backendErrorBuffer;
    QString m_activePlanPath;
    QString m_backendPurpose;

    QString m_language = QStringLiteral("English");
    QString m_timeFormat = QStringLiteral("English (United States)");
    QString m_keyboard = QStringLiteral("US");
    bool m_licenseAccepted = false;
    QString m_installType = QStringLiteral("erase");
    QString m_username;
    QString m_computerName = QStringLiteral("aero7-pc");
    QString m_password;
    QString m_passwordConfirmation;
    QString m_passwordHint;
    QString m_updatePreference = QStringLiteral("recommended");
    QString m_timezone = QStringLiteral("Europe/Amsterdam");
    QString m_networkChoice = QStringLiteral("public");
};
