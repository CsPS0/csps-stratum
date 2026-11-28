/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2025 Thomas Duckworth <tduck@filotimoproject.org>

    SPDX-License-Identifier: LGPL-2.0-or-later

    KDE Breeze's login clock (org.kde.breeze.components Clock.qml) with fixed formats: 24-hour
    "23:49" and "2026-11-27", like the top bar, instead of the locale's. The SDDM greeter ignores
    LC_TIME, so the locale gave "Friday 27 November 2026". Used by the oled-span SDDM theme
    (install-sddm-theme.sh) and by the lock screen patch (../lockscreen/oled-lockscreen-noblur),
    where the Hungarian locale gave "0:41".
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    PlasmaComponents3.Label {
        text: Qt.formatTime(timeSource.dateTime, "HH:mm")
        textFormat: Text.PlainText
        style: root.softwareRendering ? Text.Outline : Text.Normal
        styleColor: root.softwareRendering ? Kirigami.Theme.backgroundColor : "transparent"
        font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 7.2)
        font.weight: Font.DemiBold
        font.letterSpacing: -3.0
        font.wordSpacing: 3.0
        font.features: Object.assign({}, Kirigami.Theme.defaultFont.features, { "tnum": 1 })
        renderType: Text.NativeRendering
        Layout.alignment: Qt.AlignHCenter
    }
    PlasmaComponents3.Label {
        text: Qt.formatDate(timeSource.dateTime, "yyyy-MM-dd")
        textFormat: Text.PlainText
        style: root.softwareRendering ? Text.Outline : Text.Normal
        styleColor: root.softwareRendering ? Kirigami.Theme.backgroundColor : "transparent"
        font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 2.4)
        renderType: Text.NativeRendering
        Layout.alignment: Qt.AlignHCenter
    }

    PlasmaClock.Clock {
        id: timeSource
        trackSeconds: false
    }
}
