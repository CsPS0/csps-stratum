// "CPU 3%  RAM 58%  GPU 2%  <cloud> 0°C", as on the Windows top bar.
// CPU, RAM and GPU come from KDE's ksystemstats (every 2 s); the weather from wttr.in, which finds
// the location from the IP address (every 30 min; hidden until the first answer).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: 2000 }
    Sensors.Sensor { id: ram; sensorId: "memory/physical/usedPercent"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpu; sensorId: "gpu/all/usage"; updateRateLimit: 2000 }

    function pct(s) { return (s.value === undefined || isNaN(s.value)) ? "–" : Math.round(s.value) + "%" }

    property string weather: ""
    property string place: ""

    // wttr.in / WWO weather codes -> Nerd Font weather glyphs
    function icon(code) {
        const c = Number(code);
        if (c === 113) return "";                                   // clear
        if (c === 116) return "";                                   // partly cloudy
        if (c === 119 || c === 122) return "";                      // cloudy, overcast
        if ([143, 248, 260].includes(c)) return "";                 // mist, fog
        if ([200, 386, 389, 392, 395].includes(c)) return "";       // thunder
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(c)) return ""; // snow
        return "";                                                  // rain, drizzle, sleet
    }

    function fetchWeather() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return;
            try {
                const d = JSON.parse(xhr.responseText);
                const now = d.current_condition[0];
                root.weather = icon(now.weatherCode) + " " + now.temp_C + "°C";
                const area = (d.nearest_area || [])[0];
                root.place = area ? area.areaName[0].value + ": " + now.weatherDesc[0].value : now.weatherDesc[0].value;
            } catch (e) {
                // keep the last value
            }
        };
        xhr.open("GET", "https://wttr.in/?format=j1");
        xhr.send();
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchWeather()
    }
    // Retry sooner while there is no weather yet (offline at login).
    Timer {
        interval: 2 * 60 * 1000
        running: root.weather === ""
        repeat: true
        onTriggered: root.fetchWeather()
    }

    toolTipMainText: place

    fullRepresentation: RowLayout {
        spacing: 18
        Layout.preferredWidth: implicitWidth
        Layout.fillHeight: true

        // Gap before CPU (plus the row spacing), as on Windows.
        Item { Layout.preferredWidth: 6 }

        Repeater {
            model: [
                "CPU " + root.pct(cpu),
                "RAM " + root.pct(ram),
                "GPU " + root.pct(gpu),
                root.weather
            ]
            PlasmaComponents.Label {
                required property string modelData
                visible: modelData !== ""
                text: modelData
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: "#8E9194"
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
