#include "app/ScreenAwake.h"

#if defined(Q_OS_WIN)
#  include <windows.h>
#elif defined(Q_OS_ANDROID)
#  include <QCoreApplication>
#  include <QJniObject>
#endif

ScreenAwake::ScreenAwake(QObject *parent)
    : QObject(parent)
{
}

ScreenAwake::~ScreenAwake()
{
    // Never leave the display pinned awake after the app goes away.
    if (m_enabled)
        apply(false);
}

bool ScreenAwake::isSupported()
{
#if defined(Q_OS_WIN) || defined(Q_OS_ANDROID)
    return true;
#else
    return false;
#endif
}

void ScreenAwake::setEnabled(bool value)
{
    if (m_enabled == value)
        return;
    m_enabled = value;
    apply(m_enabled);
    Q_EMIT enabledChanged();
}

#if defined(Q_OS_WIN)

void ScreenAwake::apply(bool keepAwake)
{
    // ES_CONTINUOUS alone clears a previously registered request; combined with
    // the DISPLAY/SYSTEM flags it registers one that lasts until we clear it.
    if (keepAwake)
        ::SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED);
    else
        ::SetThreadExecutionState(ES_CONTINUOUS);
}

#elif defined(Q_OS_ANDROID)

void ScreenAwake::apply(bool keepAwake)
{
    // Window flags may only be touched from the Android UI thread.
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([keepAwake]() {
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid())
            return;

        QJniObject window = activity.callObjectMethod("getWindow", "()Landroid/view/Window;");
        if (!window.isValid())
            return;

        // android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        constexpr jint kFlagKeepScreenOn = 0x00000080;
        if (keepAwake)
            window.callMethod<void>("addFlags", "(I)V", kFlagKeepScreenOn);
        else
            window.callMethod<void>("clearFlags", "(I)V", kFlagKeepScreenOn);
    });
}

#else

void ScreenAwake::apply(bool)
{
}

#endif
