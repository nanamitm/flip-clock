#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QtQmlIntegration>

/*!
 * Searchable catalogue of IANA time zones, used by the "add a city" picker.
 *
 * The full list is built once and then filtered in place, so typing in the
 * search field never re-queries QTimeZone.
 */
class TimeZoneListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged FINAL)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)

public:
    enum Roles {
        TimeZoneIdRole = Qt::UserRole + 1,
        CityRole,
        RegionRole,
        OffsetTextRole,
    };
    Q_ENUM(Roles)

    explicit TimeZoneListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString filter() const { return m_filter; }
    void setFilter(const QString &value);

Q_SIGNALS:
    void filterChanged();
    void countChanged();

private:
    struct Entry
    {
        QString id;
        QString city;
        QString region;
        QString offsetText;
        QString searchKey; //!< Lower-cased "city region id", matched against the filter.
    };

    static QList<Entry> buildCatalogue();
    void applyFilter();

    QList<Entry> m_all;
    QList<int> m_visible; //!< Indices into m_all.
    QString m_filter;
};
