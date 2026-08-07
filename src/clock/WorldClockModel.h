#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QStringList>
#include <QTimeZone>
#include <QtQmlIntegration>

/*!
 * The user's chosen cities and the current time in each.
 *
 * Owns its own persistence (QSettings key \c worldClock/timeZoneIds) so there
 * is exactly one writer for that list and no two-way binding against
 * AppSettings to keep in sync.
 *
 * The rows are recomputed by refresh(), which QML calls from the clock tick
 * only while the world clock page is on screen.
 */
class WorldClockModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)
    //! Bound from AppSettings by QML, mirroring ClockController.
    Q_PROPERTY(bool use24Hour READ use24Hour WRITE setUse24Hour NOTIFY use24HourChanged FINAL)

public:
    enum Roles {
        TimeZoneIdRole = Qt::UserRole + 1,
        CityRole,
        RegionRole,
        TimeTextRole,
        MeridiemRole,
        OffsetTextRole,
        DayOffsetRole,     //!< -1, 0 or +1 relative to the local date.
        DayOffsetTextRole, //!< "" / "Tomorrow" / "Yesterday".
        IsDaylightTimeRole,
    };
    Q_ENUM(Roles)

    explicit WorldClockModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool use24Hour() const { return m_use24Hour; }
    void setUse24Hour(bool value);

    //! True when \a timeZoneId is already on the list; drives the picker's check marks.
    Q_INVOKABLE bool contains(const QString &timeZoneId) const;

    Q_INVOKABLE void add(const QString &timeZoneId);
    Q_INVOKABLE void removeAt(int row);
    Q_INVOKABLE void move(int from, int to);

    //! Re-reads the wall clock and republishes every row's time.
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void countChanged();
    void use24HourChanged();

private:
    struct Row
    {
        QString id;
        QTimeZone zone;
        QString city;
        QString region;
    };

    void load();
    void save() const;

    QList<Row> m_rows;
    QDateTime m_now;
    bool m_use24Hour = true;
};
