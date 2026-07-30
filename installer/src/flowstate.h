#pragma once

#include <QString>
#include <QStringList>

class FlowState
{
public:
    enum class Mode { Installer, Oobe };

    explicit FlowState(Mode mode = Mode::Installer);

    void setMode(Mode mode);
    [[nodiscard]] Mode mode() const;
    [[nodiscard]] QString screenId() const;
    [[nodiscard]] int index() const;
    [[nodiscard]] int count() const;
    [[nodiscard]] bool canGoBack() const;
    [[nodiscard]] bool canGoNext() const;

    bool next();
    bool back();
    void reset();
    bool jumpTo(const QString &screenId);

private:
    static QStringList screensFor(Mode mode);

    Mode m_mode;
    QStringList m_screens;
    int m_index = 0;
};

