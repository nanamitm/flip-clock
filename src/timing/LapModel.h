#pragma once

#include <QAbstractListModel>
#include <QtQmlIntegration>

/*!
 * Recorded stopwatch laps, newest first.
 *
 * Tracks which lap is fastest and slowest as laps are added, so the list can
 * highlight them without rescanning on every repaint.
 */
class LapModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Obtained from Stopwatch.laps")

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)

public:
    enum Roles {
        LapNumberRole = Qt::UserRole + 1,
        LapTextRole,     //!< Duration of this lap alone.
        TotalTextRole,   //!< Elapsed time when the lap was taken.
        IsFastestRole,
        IsSlowestRole,
    };
    Q_ENUM(Roles)

    explicit LapModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    //! \a totalMs is the stopwatch reading at the moment the lap was taken.
    void addLap(qint64 totalMs);
    void clear();

    //! Formats \a ms as m:ss.hh (or h:mm:ss.hh past an hour).
    static QString formatDuration(qint64 ms);

Q_SIGNALS:
    void countChanged();

private:
    struct Lap
    {
        int number;
        qint64 lapMs;
        qint64 totalMs;
    };

    //! Recomputes the fastest/slowest indices and repaints the affected rows.
    void updateExtremes();

    //! Newest lap first, so m_laps.first() is the most recent.
    QList<Lap> m_laps;
    int m_fastestNumber = -1;
    int m_slowestNumber = -1;
};
