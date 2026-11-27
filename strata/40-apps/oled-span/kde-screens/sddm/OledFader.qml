/*
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>

    SPDX-License-Identifier: GPL-2.0-or-later

    KDE Breeze's WallpaperFader (org.kde.breeze.components) without its picture effects. Breeze
    blurs the wallpaper and lifts its blacks to grey (contrast 0.8, intensity 0.7) while the login
    form shows; this keeps only the fading of the form, clock and footer, so the OLED Span contours
    stay crisp and black. Used by the oled-span SDDM theme (install-sddm-theme.sh).
*/

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: wallpaperFader

    property Item clock
    property Item mainStack
    property Item footer
    property Item source          // unused: the wallpaper is left as it is
    property real factor: 0
    property bool alwaysShowClock: false

    state: "on"

    states: [
        State {
            name: "on"
            PropertyChanges {
                mainStack.opacity: 1
                wallpaperFader.factor: 1
                clock.shadow.opacity: 0
                clock.opacity: 1
            }
            PropertyChanges {
                target: footer
                opacity: 1
            }
        },
        State {
            name: "off"
            PropertyChanges {
                mainStack.opacity: 0
                wallpaperFader.factor: 0
                clock.shadow.opacity: wallpaperFader.alwaysShowClock ? 1 : 0
                clock.opacity: wallpaperFader.alwaysShowClock ? 1 : 0
            }
            PropertyChanges {
                target: footer
                opacity: 0
            }
        }
    ]

    transitions: [
        Transition {
            from: "off"
            to: "on"
            NumberAnimation {
                targets: [wallpaperFader.mainStack, wallpaperFader.footer, wallpaperFader.clock]
                property: "opacity"
                duration: Kirigami.Units.veryLongDuration
                easing.type: Easing.InOutQuad
            }
        },
        Transition {
            from: "on"
            to: "off"
            NumberAnimation {
                targets: [wallpaperFader.mainStack, wallpaperFader.footer, wallpaperFader.clock]
                property: "opacity"
                duration: Kirigami.Units.veryLongDuration
                easing.type: Easing.InOutQuad
            }
        }
    ]
}
