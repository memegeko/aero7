#include "installercontroller.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>

namespace {
const QStringList kInstallStages = {
    QStringLiteral("Preparing disk"),
    QStringLiteral("Copying system files"),
    QStringLiteral("Installing the base system"),
    QStringLiteral("Installing Aero7 features"),
    QStringLiteral("Configuring the bootloader"),
    QStringLiteral("Applying system settings"),
    QStringLiteral("Preparing first boot"),
};
const QString kFirstLoginCleanupTimer =
    QStringLiteral("aero7-first-login-cleanup.timer");
}

InstallerController::InstallerController(bool oobeMode, bool demoMode,
                                         QString backendPath, QObject *parent)
    : QObject(parent),
      m_flow(oobeMode ? FlowState::Mode::Oobe : FlowState::Mode::Installer),
      m_initialOobeMode(oobeMode),
      m_oobeMode(oobeMode),
      m_demoMode(demoMode),
      m_backendPath(std::move(backendPath))
{
    m_transitionTimer.setSingleShot(true);
    connect(&m_transitionTimer, &QTimer::timeout, this, &InstallerController::advanceTransition);
    m_progressTimer.setInterval(220);
    connect(&m_progressTimer, &QTimer::timeout, this, &InstallerController::advanceDemoProgress);
    m_restartTimer.setInterval(1000);
    connect(&m_restartTimer, &QTimer::timeout, this, &InstallerController::tickRestartCountdown);
    m_desktopHandoffTimer.setSingleShot(true);
    connect(&m_desktopHandoffTimer, &QTimer::timeout,
            this, &InstallerController::handoffToDesktop);
    connect(&m_backend, &QProcess::readyReadStandardOutput, this, &InstallerController::readBackendOutput);
    connect(&m_backend, &QProcess::readyReadStandardError, this, [this] {
        const QString text = QString::fromUtf8(m_backend.readAllStandardError()).trimmed();
        if (!text.isEmpty())
            setStatus(text);
    });
    connect(&m_backend, qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
            this, &InstallerController::backendFinished);

    if (!m_oobeMode)
        refreshDisks();
    enterCurrentScreen();
}

QString InstallerController::screenId() const { return m_flow.screenId(); }
bool InstallerController::oobeMode() const { return m_oobeMode; }
bool InstallerController::demoMode() const { return m_demoMode; }
bool InstallerController::canGoBack() const
{
    const QString current = screenId();
    return m_flow.canGoBack() && current != QStringLiteral("StartingScreen")
        && current != QStringLiteral("ProgressScreen")
        && current != QStringLiteral("CompleteScreen")
        && current != QStringLiteral("ApplyingSettingsScreen")
        && current != QStringLiteral("VideoPerformanceScreen")
        && current != QStringLiteral("AccountScreen")
        && current != QStringLiteral("FinalizingScreen")
        && current != QStringLiteral("OobeWelcomeScreen")
        && current != QStringLiteral("PreparingDesktopScreen")
        && current != QStringLiteral("DesktopScreen");
}
QVariantList InstallerController::disks() const { return m_disks; }
QVariantMap InstallerController::selectedDisk() const { return m_selectedDisk; }
int InstallerController::progress() const { return m_progress; }
int InstallerController::progressStageIndex() const { return m_progressStageIndex; }
QString InstallerController::progressStage() const { return m_progressStage; }
QString InstallerController::statusText() const { return m_statusText; }
bool InstallerController::busy() const { return m_busy; }
int InstallerController::restartSeconds() const { return m_restartSeconds; }
bool InstallerController::desktopHandoff() const { return m_desktopHandoff; }

void InstallerController::goNext()
{
    if (m_busy || !validateCurrentScreen())
        return;

    if (screenId() == QStringLiteral("ConfirmScreen")) {
        startInstallation();
        return;
    }
    if (screenId() == QStringLiteral("NetworkScreen")) {
        startOobeFinalization();
        return;
    }
    if (screenId() == QStringLiteral("CompleteScreen")) {
        continueAfterInstallation();
        return;
    }
    if (screenId() == QStringLiteral("OobeWelcomeScreen")) {
        moveNext();
        return;
    }
    if (screenId() == QStringLiteral("DesktopScreen")) {
        resetDemo();
        return;
    }
    moveNext();
}

void InstallerController::goBack()
{
    if (m_busy || !canGoBack())
        return;
    if (m_flow.back()) {
        setStatus({});
        emit screenChanged();
        enterCurrentScreen();
    }
}

void InstallerController::moveNext()
{
    if (!m_flow.next())
        return;
    setStatus({});
    emit screenChanged();
    enterCurrentScreen();
}

void InstallerController::advanceTransition()
{
    setBusy(false);
    if (screenId() == QStringLiteral("PreparingDesktopScreen") && !m_demoMode) {
        beginDesktopHandoff();
        return;
    }
    moveNext();
}

void InstallerController::enterCurrentScreen()
{
    m_transitionTimer.stop();
    setBusy(false);
    if (screenId() != QStringLiteral("CompleteScreen"))
        m_restartTimer.stop();

    const QString current = screenId();
    int delay = 0;
    if (current == QStringLiteral("StartingScreen"))
        delay = 1300;
    else if (current == QStringLiteral("ApplyingSettingsScreen"))
        delay = 1900;
    else if (current == QStringLiteral("VideoPerformanceScreen"))
        delay = 2300;
    else if (current == QStringLiteral("OobeWelcomeScreen"))
        delay = 1700;
    else if (current == QStringLiteral("PreparingDesktopScreen"))
        delay = 2400;

    if (delay > 0) {
        setBusy(true);
        m_transitionTimer.start(delay);
    }

    if (current == QStringLiteral("CompleteScreen")) {
        m_restartSeconds = 10;
        emit restartSecondsChanged();
        m_restartTimer.start();
    }
}

void InstallerController::beginDesktopHandoff()
{
    if (m_desktopHandoff)
        return;
    m_desktopHandoff = true;
    emit desktopHandoffChanged();
    setBusy(true);
    m_desktopHandoffTimer.start(950);
}

void InstallerController::handoffToDesktop()
{
    if (m_demoMode)
        return;

    const int cleanupStatus = QProcess::execute(
        QStringLiteral("/usr/bin/systemctl"),
        {QStringLiteral("is-active"), QStringLiteral("--quiet"),
         kFirstLoginCleanupTimer});
    if (cleanupStatus != 0) {
        m_desktopHandoff = false;
        emit desktopHandoffChanged();
        setBusy(false);
        setStatus(QStringLiteral("Setup could not secure the one-time automatic login. The desktop was not started."));
        return;
    }

    const int startStatus = QProcess::execute(
        QStringLiteral("/usr/bin/systemctl"),
        {QStringLiteral("--no-block"), QStringLiteral("start"),
         QStringLiteral("sddm.service")});
    if (startStatus != 0) {
        m_desktopHandoff = false;
        emit desktopHandoffChanged();
        setBusy(false);
        setStatus(QStringLiteral("Setup could not start the Aero7 desktop."));
    }
}

void InstallerController::tickRestartCountdown()
{
    if (screenId() != QStringLiteral("CompleteScreen")) {
        m_restartTimer.stop();
        return;
    }
    m_restartSeconds = qMax(0, m_restartSeconds - 1);
    emit restartSecondsChanged();
    if (m_restartSeconds > 0)
        return;
    m_restartTimer.stop();
    continueAfterInstallation();
}

void InstallerController::continueAfterInstallation()
{
    m_restartTimer.stop();
    if (!m_demoMode) {
        restartSystem();
        return;
    }
    enterOobeFlow();
}

void InstallerController::enterOobeFlow()
{
    m_flow.setMode(FlowState::Mode::Oobe);
    if (!m_oobeMode) {
        m_oobeMode = true;
        emit oobeModeChanged();
    }
    m_progress = 0;
    m_progressStageIndex = 0;
    m_progressStage.clear();
    setStatus({});
    emit progressChanged();
    emit screenChanged();
    enterCurrentScreen();
}

bool InstallerController::validateCurrentScreen()
{
    const QString current = screenId();
    if (current == QStringLiteral("LicenseScreen") && !m_licenseAccepted) {
        setStatus(QStringLiteral("Accept the Aero7 license terms to continue."));
        return false;
    }
    if (current == QStringLiteral("DiskScreen") && m_selectedDisk.isEmpty()) {
        setStatus(QStringLiteral("Select a target disk."));
        return false;
    }
    if (current == QStringLiteral("AccountScreen")) {
        if (m_username.length() < 2 || m_computerName.length() < 2) {
            setStatus(QStringLiteral("Enter a username and computer name."));
            return false;
        }
        const QRegularExpression safe(QStringLiteral("^[a-z_][a-z0-9_-]*$"));
        if (!safe.match(m_username).hasMatch()) {
            setStatus(QStringLiteral("Username must use lowercase letters, numbers, '_' or '-'."));
            return false;
        }
        const QRegularExpression hostname(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9-]{0,62}$"));
        if (!hostname.match(m_computerName).hasMatch()) {
            setStatus(QStringLiteral("Computer name must use letters, numbers, or '-' and cannot begin with '-'."));
            return false;
        }
    }
    if (current == QStringLiteral("PasswordScreen")) {
        if (m_password.length() < 8) {
            setStatus(QStringLiteral("Use a password with at least 8 characters."));
            return false;
        }
        if (m_password != m_passwordConfirmation) {
            setStatus(QStringLiteral("The passwords do not match."));
            return false;
        }
        if (m_password.contains(QLatin1Char(':')) || m_password.contains(QLatin1Char('\n'))) {
            setStatus(QStringLiteral("The password cannot contain ':' or a line break."));
            return false;
        }
    }
    return true;
}

void InstallerController::selectDisk(int index)
{
    if (index < 0 || index >= m_disks.size())
        return;
    m_selectedDisk = m_disks.at(index).toMap();
    setStatus({});
    emit selectedDiskChanged();
}

void InstallerController::refreshDisks()
{
    m_disks.clear();
    m_selectedDisk.clear();
    if (m_demoMode) {
        m_disks.append(QVariantMap{
            {QStringLiteral("device"), QStringLiteral("/dev/vda")},
            {QStringLiteral("model"), QStringLiteral("QEMU HARDDISK (simulation)")},
            {QStringLiteral("size"), QStringLiteral("40.0 GiB")},
            {QStringLiteral("free_space"), QStringLiteral("40.0 GiB")},
            {QStringLiteral("type"), QStringLiteral("")},
            {QStringLiteral("size_bytes"), 42949672960ULL},
            {QStringLiteral("serial"), QStringLiteral("AERO7-DEMO-0001")},
            {QStringLiteral("maj_min"), QStringLiteral("252:0")},
            {QStringLiteral("kname"), QStringLiteral("vda")},
        });
        m_selectedDisk = m_disks.first().toMap();
    } else {
        QProcess scan;
        scan.start(m_backendPath, {QStringLiteral("list-disks"), QStringLiteral("--json")});
        if (scan.waitForFinished(5000) && scan.exitCode() == 0) {
            const QJsonDocument document = QJsonDocument::fromJson(scan.readAllStandardOutput());
            for (const QJsonValue &value : document.array())
                m_disks.append(value.toObject().toVariantMap());
        } else {
            setStatus(QStringLiteral("Disk scan failed: %1")
                          .arg(QString::fromUtf8(scan.readAllStandardError()).trimmed()));
        }
    }
    emit disksChanged();
    emit selectedDiskChanged();
}

void InstallerController::openRecoveryShell()
{
    if (m_demoMode) {
        setStatus(QStringLiteral("Recovery opens the root console on TTY2 in the live installation media."));
        return;
    }

    const int gettyStatus = QProcess::execute(
        QStringLiteral("/usr/bin/systemctl"),
        {QStringLiteral("start"), QStringLiteral("getty@tty2.service")});
    if (gettyStatus != 0) {
        setStatus(QStringLiteral("Setup could not start the recovery console."));
        return;
    }

    const int switchStatus = QProcess::execute(
        QStringLiteral("/usr/bin/chvt"), {QStringLiteral("2")});
    if (switchStatus != 0)
        setStatus(QStringLiteral("Recovery is running on TTY2. Press Alt+F2 to open it."));
}

void InstallerController::startInstallation()
{
    if (m_selectedDisk.isEmpty()) {
        setStatus(QStringLiteral("The selected disk is no longer available."));
        return;
    }
    m_flow.jumpTo(QStringLiteral("ProgressScreen"));
    m_progress = 0;
    m_progressStageIndex = 0;
    m_progressStage = kInstallStages.first();
    setBusy(true);
    emit screenChanged();
    emit progressChanged();

    if (m_demoMode) {
        startDemoProgress(false);
        return;
    }

    const QString planPath = writeInstallPlan();
    if (planPath.isEmpty()) {
        setBusy(false);
        setStatus(QStringLiteral("Could not create the protected installation plan."));
        return;
    }
    startBackend({QStringLiteral("install"), QStringLiteral("--plan"), planPath,
                  QStringLiteral("--confirm-device"), m_selectedDisk.value(QStringLiteral("device")).toString(),
                  QStringLiteral("--execute")}, planPath);
}

void InstallerController::startOobeFinalization()
{
    m_flow.jumpTo(QStringLiteral("FinalizingScreen"));
    m_progress = 0;
    m_progressStageIndex = 0;
    m_progressStage = QStringLiteral("Applying your settings");
    setBusy(true);
    emit screenChanged();
    emit progressChanged();

    if (m_demoMode) {
        startDemoProgress(true);
        return;
    }

    const QString planPath = writeOobePlan();
    if (planPath.isEmpty()) {
        setBusy(false);
        setStatus(QStringLiteral("Could not create the protected OOBE plan."));
        return;
    }
    startBackend({QStringLiteral("oobe-finalize"), QStringLiteral("--plan"), planPath}, planPath);
}

void InstallerController::startDemoProgress(bool oobe)
{
    m_progressTimer.setProperty("oobe", oobe);
    m_progressTimer.start();
}

void InstallerController::advanceDemoProgress()
{
    m_progress = qMin(100, m_progress + 4);
    const bool oobe = m_progressTimer.property("oobe").toBool();
    if (!oobe) {
        m_progressStageIndex = qMin(kInstallStages.size() - 1, (m_progress * kInstallStages.size()) / 101);
        m_progressStage = kInstallStages.at(m_progressStageIndex);
    } else if (m_progress > 55) {
        m_progressStage = QStringLiteral("Preparing the Aero7 desktop");
    }
    emit progressChanged();

    if (m_progress < 100)
        return;
    m_progressTimer.stop();
    setBusy(false);
    m_flow.jumpTo(oobe ? QStringLiteral("OobeWelcomeScreen") : QStringLiteral("CompleteScreen"));
    emit screenChanged();
    enterCurrentScreen();
}

QString InstallerController::writeInstallPlan() const
{
    QDir().mkpath(QStringLiteral("/run/aero7"));
    const QString path = QStringLiteral("/run/aero7/install-plan.json");
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return {};
    QJsonObject object = QJsonObject::fromVariantMap(m_selectedDisk);
    object.insert(QStringLiteral("layout"), QStringLiteral("uefi-gpt-esp-ext4"));
    object.insert(QStringLiteral("language"), m_language);
    object.insert(QStringLiteral("keyboard"), m_keyboard);
    file.write(QJsonDocument(object).toJson(QJsonDocument::Indented));
    if (!file.commit())
        return {};
    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return path;
}

QString InstallerController::writeOobePlan() const
{
    QDir().mkpath(QStringLiteral("/run/aero7"));
    const QString path = QStringLiteral("/run/aero7/oobe-plan.json");
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return {};
    const QJsonObject object{
        {QStringLiteral("username"), m_username},
        {QStringLiteral("computer_name"), m_computerName},
        {QStringLiteral("password"), m_password},
        {QStringLiteral("update_preference"), m_updatePreference},
        {QStringLiteral("timezone"), m_timezone},
        {QStringLiteral("network"), m_networkChoice},
    };
    file.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
    if (!file.commit())
        return {};
    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return path;
}

void InstallerController::startBackend(const QStringList &arguments, const QString &planPath)
{
    m_activePlanPath = planPath;
    m_backendBuffer.clear();
    m_backend.setProcessChannelMode(QProcess::SeparateChannels);
    m_backend.start(m_backendPath, arguments);
    if (!m_backend.waitForStarted(3000)) {
        setBusy(false);
        setStatus(QStringLiteral("Could not start privileged backend: %1").arg(m_backend.errorString()));
    }
}

void InstallerController::readBackendOutput()
{
    m_backendBuffer.append(m_backend.readAllStandardOutput());
    while (true) {
        const qsizetype newline = m_backendBuffer.indexOf('\n');
        if (newline < 0)
            break;
        const QByteArray line = m_backendBuffer.left(newline).trimmed();
        m_backendBuffer.remove(0, newline + 1);
        if (!line.isEmpty())
            handleBackendEvent(line);
    }
}

void InstallerController::handleBackendEvent(const QByteArray &line)
{
    const QJsonObject event = QJsonDocument::fromJson(line).object();
    const QString type = event.value(QStringLiteral("type")).toString();
    if (type == QStringLiteral("progress")) {
        m_progress = event.value(QStringLiteral("percent")).toInt(m_progress);
        m_progressStage = event.value(QStringLiteral("stage")).toString(m_progressStage);
        const int stage = kInstallStages.indexOf(m_progressStage);
        if (stage >= 0)
            m_progressStageIndex = stage;
        emit progressChanged();
    } else if (type == QStringLiteral("status")) {
        setStatus(event.value(QStringLiteral("message")).toString());
    }
}

void InstallerController::backendFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (!m_activePlanPath.isEmpty()) {
        QFile::remove(m_activePlanPath);
        m_activePlanPath.clear();
    }
    setBusy(false);
    if (exitStatus != QProcess::NormalExit || exitCode != 0) {
        const QString detail = m_statusText.trimmed();
        if (detail.isEmpty()) {
            setStatus(QStringLiteral("Setup stopped safely. Backend exit code: %1").arg(exitCode));
        } else if (!detail.startsWith(QStringLiteral("Setup stopped safely."))) {
            setStatus(QStringLiteral("Setup stopped safely. %1").arg(detail));
        }
        return;
    }
    m_progress = 100;
    emit progressChanged();
    m_flow.jumpTo(m_oobeMode ? QStringLiteral("OobeWelcomeScreen") : QStringLiteral("CompleteScreen"));
    emit screenChanged();
    enterCurrentScreen();
}

void InstallerController::restartSystem()
{
    if (m_demoMode) {
        resetDemo();
        return;
    }
    QProcess::startDetached(QStringLiteral("/usr/bin/systemctl"), {QStringLiteral("reboot")});
}

void InstallerController::resetDemo()
{
    m_progressTimer.stop();
    m_transitionTimer.stop();
    m_restartTimer.stop();
    m_desktopHandoffTimer.stop();
    if (m_desktopHandoff) {
        m_desktopHandoff = false;
        emit desktopHandoffChanged();
    }
    m_flow.setMode(m_initialOobeMode ? FlowState::Mode::Oobe : FlowState::Mode::Installer);
    if (m_oobeMode != m_initialOobeMode) {
        m_oobeMode = m_initialOobeMode;
        emit oobeModeChanged();
    }
    m_progress = 0;
    m_progressStageIndex = 0;
    m_progressStage.clear();
    m_licenseAccepted = false;
    m_username.clear();
    m_computerName = QStringLiteral("aero7-pc");
    m_password.clear();
    m_passwordConfirmation.clear();
    m_passwordHint.clear();
    setBusy(false);
    setStatus({});
    emit progressChanged();
    emit formChanged();
    emit screenChanged();
    enterCurrentScreen();
}

bool InstallerController::jumpToForTest(const QString &screen)
{
    if (!m_demoMode || !m_flow.jumpTo(screen))
        return false;
    emit screenChanged();
    enterCurrentScreen();
    return true;
}

void InstallerController::setStatus(const QString &text)
{
    if (m_statusText == text)
        return;
    m_statusText = text;
    emit statusChanged();
}

void InstallerController::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}
