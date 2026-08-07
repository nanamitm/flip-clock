#include "theme/ThemeManager.h"

#include <QVariantMap>

const QList<ThemeManager::Palette> &ThemeManager::catalogue()
{
    static const QList<Palette> palettes = {
        Palette{
            QStringLiteral("midnight"), QStringLiteral("Midnight"), true,
            QColor(0x0b, 0x0c, 0x10), // background
            QColor(0x16, 0x18, 0x20), // surface
            QColor(0x1f, 0x22, 0x2c), // surfaceAlt
            QColor(0x25, 0x29, 0x36), // cardTop
            QColor(0x1a, 0x1d, 0x27), // cardBottom
            QColor(0xf3, 0xf5, 0xff), // digit
            QColor(0x0b, 0x0c, 0x10), // divider
            QColor(0x5b, 0x8d, 0xef), // accent
            QColor(0xf0, 0xf2, 0xf8), // textPrimary
            QColor(0x94, 0x9a, 0xad), // textSecondary
        },
        Palette{
            QStringLiteral("charcoal"), QStringLiteral("Charcoal"), true,
            QColor(0x12, 0x12, 0x12),
            QColor(0x1c, 0x1c, 0x1c),
            QColor(0x26, 0x26, 0x26),
            QColor(0x33, 0x33, 0x33),
            QColor(0x24, 0x24, 0x24),
            QColor(0xfa, 0xfa, 0xfa),
            QColor(0x0d, 0x0d, 0x0d),
            QColor(0xe0, 0xe0, 0xe0),
            QColor(0xf5, 0xf5, 0xf5),
            QColor(0x9e, 0x9e, 0x9e),
        },
        Palette{
            QStringLiteral("amber"), QStringLiteral("Amber"), true,
            QColor(0x12, 0x0d, 0x06),
            QColor(0x1e, 0x15, 0x0a),
            QColor(0x2a, 0x1e, 0x0e),
            QColor(0x33, 0x24, 0x10),
            QColor(0x23, 0x18, 0x0a),
            QColor(0xff, 0xb3, 0x3a),
            QColor(0x0a, 0x07, 0x03),
            QColor(0xff, 0x8f, 0x1f),
            QColor(0xff, 0xe2, 0xb8),
            QColor(0xb2, 0x8a, 0x5c),
        },
        Palette{
            QStringLiteral("neon"), QStringLiteral("Neon"), true,
            QColor(0x07, 0x0a, 0x14),
            QColor(0x0f, 0x15, 0x24),
            QColor(0x17, 0x1f, 0x33),
            QColor(0x14, 0x1d, 0x33),
            QColor(0x0c, 0x13, 0x23),
            QColor(0x4d, 0xf7, 0xd8),
            QColor(0x05, 0x07, 0x0d),
            QColor(0xff, 0x3d, 0x9a),
            QColor(0xe6, 0xfa, 0xff),
            QColor(0x6f, 0x8a, 0xa8),
        },
        Palette{
            QStringLiteral("paper"), QStringLiteral("Paper"), false,
            QColor(0xf4, 0xf1, 0xea),
            QColor(0xff, 0xff, 0xff),
            QColor(0xe9, 0xe4, 0xd9),
            QColor(0xff, 0xfd, 0xf8),
            QColor(0xec, 0xe7, 0xdc),
            QColor(0x24, 0x22, 0x1e),
            QColor(0xd3, 0xcc, 0xbe),
            QColor(0xc0, 0x6a, 0x2e),
            QColor(0x24, 0x22, 0x1e),
            QColor(0x76, 0x70, 0x66),
        },
        Palette{
            QStringLiteral("ocean"), QStringLiteral("Ocean"), true,
            QColor(0x05, 0x16, 0x1f),
            QColor(0x0b, 0x24, 0x31),
            QColor(0x10, 0x30, 0x40),
            QColor(0x13, 0x39, 0x4b),
            QColor(0x0a, 0x26, 0x34),
            QColor(0xdf, 0xf6, 0xff),
            QColor(0x03, 0x0f, 0x16),
            QColor(0x3a, 0xc8, 0xd6),
            QColor(0xe8, 0xf8, 0xff),
            QColor(0x7d, 0xa3, 0xb3),
        },
    };
    return palettes;
}

ThemeManager::ThemeManager(QObject *parent)
    : QObject(parent)
    , m_palette(catalogue().first())
{
}

void ThemeManager::setThemeId(const QString &id)
{
    if (id == m_palette.id)
        return;

    for (const Palette &palette : catalogue()) {
        if (palette.id == id) {
            m_palette = palette;
            Q_EMIT themeChanged();
            return;
        }
    }
    // Unknown id (stale setting, or a palette removed in a later version):
    // keep the current palette rather than leaving the UI unstyled.
}

QVariantList ThemeManager::themes() const
{
    QVariantList list;
    const QList<Palette> &palettes = catalogue();
    list.reserve(palettes.size());
    for (const Palette &palette : palettes) {
        list.append(QVariantMap{
            {QStringLiteral("id"), palette.id},
            {QStringLiteral("name"), palette.name},
            {QStringLiteral("background"), palette.background},
            {QStringLiteral("cardTop"), palette.cardTop},
            {QStringLiteral("cardBottom"), palette.cardBottom},
            {QStringLiteral("digit"), palette.digit},
            {QStringLiteral("accent"), palette.accent},
        });
    }
    return list;
}
