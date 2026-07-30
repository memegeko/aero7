#include "flowstate.h"

FlowState::FlowState(Mode mode)
    : m_mode(mode), m_screens(screensFor(mode))
{
}

void FlowState::setMode(Mode mode)
{
    m_mode = mode;
    m_screens = screensFor(mode);
    m_index = 0;
}

FlowState::Mode FlowState::mode() const { return m_mode; }
QString FlowState::screenId() const { return m_screens.value(m_index); }
int FlowState::index() const { return m_index; }
int FlowState::count() const { return m_screens.size(); }
bool FlowState::canGoBack() const { return m_index > 0; }
bool FlowState::canGoNext() const { return m_index + 1 < m_screens.size(); }

bool FlowState::next()
{
    if (!canGoNext())
        return false;
    ++m_index;
    return true;
}

bool FlowState::back()
{
    if (!canGoBack())
        return false;
    --m_index;
    return true;
}

void FlowState::reset() { m_index = 0; }

bool FlowState::jumpTo(const QString &screenId)
{
    const int target = m_screens.indexOf(screenId);
    if (target < 0)
        return false;
    m_index = target;
    return true;
}

QStringList FlowState::screensFor(Mode mode)
{
    if (mode == Mode::Oobe) {
        return {
            QStringLiteral("ApplyingSettingsScreen"),
            QStringLiteral("VideoPerformanceScreen"),
            QStringLiteral("AccountScreen"),
            QStringLiteral("PasswordScreen"),
            QStringLiteral("UpdatesScreen"),
            QStringLiteral("TimeScreen"),
            QStringLiteral("NetworkScreen"),
            QStringLiteral("FinalizingScreen"),
            QStringLiteral("OobeWelcomeScreen"),
            QStringLiteral("PreparingDesktopScreen"),
            QStringLiteral("DesktopScreen"),
        };
    }
    return {
        QStringLiteral("LanguageScreen"),
        QStringLiteral("WelcomeScreen"),
        QStringLiteral("StartingScreen"),
        QStringLiteral("LicenseScreen"),
        QStringLiteral("InstallTypeScreen"),
        QStringLiteral("DiskScreen"),
        QStringLiteral("ConfirmScreen"),
        QStringLiteral("ProgressScreen"),
        QStringLiteral("CompleteScreen"),
    };
}
