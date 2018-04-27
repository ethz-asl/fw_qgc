/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs          1.2
import QtLocation               5.3
import QtPositioning            5.3
import QtMultimedia             5.5
import QtQuick.Layouts          1.2
import QtQuick.Window           2.2

import QGroundControl               1.0
import QGroundControl.FlightDisplay 1.0
import QGroundControl.FlightMap     1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.Vehicle       1.0
import QGroundControl.Controllers   1.0
import QGroundControl.FactSystem    1.0

/// Flight Display View
QGCView {
    id:             root
    viewPanel:      _panel

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    property alias  guidedController:   guidedActionsController

    property bool activeVehicleJoystickEnabled: _activeVehicle ? _activeVehicle.joystickEnabled : false

    property var    _planMasterController:  masterController
    property var    _missionController:     _planMasterController.missionController
    property var    _geoFenceController:    _planMasterController.geoFenceController
    property var    _rallyPointController:  _planMasterController.rallyPointController
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property bool   _mainIsMap:             QGroundControl.videoManager.hasVideo ? QGroundControl.loadBoolGlobalSetting(_mainIsMapKey,  true) : true
    property bool   _isPipVisible:          QGroundControl.videoManager.hasVideo ? QGroundControl.loadBoolGlobalSetting(_PIPVisibleKey, true) : false
    property real   _savedZoomLevel:        0
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property real   _pipSize:               flightView.width * 0.2
    property alias  _guidedController:      guidedActionsController
    property alias  _altitudeSlider:        altitudeSlider


    readonly property var       _dynamicCameras:        _activeVehicle ? _activeVehicle.dynamicCameras : null
    readonly property bool      _isCamera:              _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    readonly property bool      isBackgroundDark:       _mainIsMap ? (_flightMap ? _flightMap.isSatelliteMap : true) : true
    readonly property real      _defaultRoll:           0
    readonly property real      _defaultPitch:          0
    readonly property real      _defaultHeading:        0
    readonly property real      _defaultAltitudeAMSL:   0
    readonly property real      _defaultGroundSpeed:    0
    readonly property real      _defaultAirSpeed:       0
    readonly property string    _mapName:               "FlightDisplayView"
    readonly property string    _showMapBackgroundKey:  "/showMapBackground"
    readonly property string    _mainIsMapKey:          "MainFlyWindowIsMap"
    readonly property string    _PIPVisibleKey:         "IsPIPVisible"

    function setStates() {
        QGroundControl.saveBoolGlobalSetting(_mainIsMapKey, _mainIsMap)
        if(_mainIsMap) {
            //-- Adjust Margins
            _flightMapContainer.state   = "fullMode"
            _flightVideo.state          = "pipMode"
            //-- Save/Restore Map Zoom Level
            if(_savedZoomLevel != 0)
                _flightMap.zoomLevel = _savedZoomLevel
            else
                _savedZoomLevel = _flightMap.zoomLevel
        } else {
            //-- Adjust Margins
            _flightMapContainer.state   = "pipMode"
            _flightVideo.state          = "fullMode"
            //-- Set Map Zoom Level
            _savedZoomLevel = _flightMap.zoomLevel
            _flightMap.zoomLevel = _savedZoomLevel - 3
        }
    }

    function setPipVisibility(state) {
        _isPipVisible = state;
        QGroundControl.saveBoolGlobalSetting(_PIPVisibleKey, state)
    }

    function isInstrumentRight() {
        if(QGroundControl.corePlugin.options.instrumentWidget) {
            if(QGroundControl.corePlugin.options.instrumentWidget.source.toString().length) {
                switch(QGroundControl.corePlugin.options.instrumentWidget.widgetPosition) {
                case CustomInstrumentWidget.POS_TOP_LEFT:
                case CustomInstrumentWidget.POS_BOTTOM_LEFT:
                case CustomInstrumentWidget.POS_CENTER_LEFT:
                    return false;
                }
            }
        }
        return true;
    }

    PlanMasterController {
        id:                     masterController
        Component.onCompleted:  start(false /* editMode */)
    }

    Connections {
        target:                     _missionController
        onResumeMissionReady:       guidedActionsController.confirmAction(guidedActionsController.actionResumeMissionReady)
        onResumeMissionUploadFail:  guidedActionsController.confirmAction(guidedActionsController.actionResumeMissionUploadFail)
    }

    Component.onCompleted: {
        setStates()
        if(QGroundControl.corePlugin.options.flyViewOverlay.toString().length) {
            flyViewOverlay.source = QGroundControl.corePlugin.options.flyViewOverlay
        }
    }

    // The following code is used to track vehicle states such that we prompt to remove mission from vehicle when mission completes

    property bool vehicleArmed:                 _activeVehicle ? _activeVehicle.armed : true // true here prevents pop up from showing during shutdown
    property bool vehicleWasArmed:              false
    property bool vehicleInMissionFlightMode:   _activeVehicle ? (_activeVehicle.flightMode === _activeVehicle.missionFlightMode) : false
    property bool promptForMissionRemove:       false

    onVehicleArmedChanged: {
        if (vehicleArmed) {
            if (!promptForMissionRemove) {
                promptForMissionRemove = vehicleInMissionFlightMode
                vehicleWasArmed = true
            }
        } else {
            if (promptForMissionRemove && (_missionController.containsItems || _geoFenceController.containsItems || _rallyPointController.containsItems)) {
                // ArduPilot has a strange bug which prevents mission clear from working at certain times, so we can't show this dialog
                if (!_activeVehicle.apmFirmware) {
                    root.showDialog(missionCompleteDialogComponent, qsTr("Flight Plan complete"), showDialogDefaultWidth, StandardButton.Close)
                }
            }
            promptForMissionRemove = false
        }
    }

    onVehicleInMissionFlightModeChanged: {
        if (!promptForMissionRemove && vehicleArmed) {
            promptForMissionRemove = true
        }
    }

    Component {
        id: missionCompleteDialogComponent

        QGCViewDialog {
            QGCFlickable {
                anchors.fill:   parent
                contentHeight:  column.height

                ColumnLayout {
                    id:                 column
                    anchors.margins:    _margins
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            ScreenTools.defaultFontPixelHeight

                    QGCLabel {
                        Layout.fillWidth:       true
                        text:                   qsTr("%1 Images Taken").arg(_activeVehicle.cameraTriggerPoints.count)
                        horizontalAlignment:    Text.AlignHCenter
                        visible:                _activeVehicle.cameraTriggerPoints.count != 0
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Remove plan from vehicle")
                        onClicked: {
                            _planMasterController.removeAllFromVehicle()
                            hideDialog()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Leave plan on vehicle")
                        anchors.horizontalCenter:   parent.horizontalCenter
                        onClicked:                  hideDialog()
                    }
                }
            }
        }
    }

    Window {
        id:             videoWindow
        width:          !_mainIsMap ? _panel.width  : _pipSize
        height:         !_mainIsMap ? _panel.height : _pipSize * (9/16)
        visible:        false

        Item {
            id:             videoItem
            anchors.fill:   parent
        }

        onClosing: {
            _flightVideo.state = "unpopup"
            videoWindow.visible = false
        }

    }

    QGCMapPalette { id: mapPal; lightColors: _mainIsMap ? _flightMap.isSatelliteMap : true }

    QGCViewPanel {
        id:             _panel
        anchors.fill:   parent

        //-- Map View
        //   For whatever reason, if FlightDisplayViewMap is the _panel item, changing
        //   width/height has no effect.
        Item {
            id: _flightMapContainer
            z:  _mainIsMap ? _panel.z + 1 : _panel.z + 2
            anchors.left:   _panel.left
            anchors.bottom: _panel.bottom
            visible:        _mainIsMap || _isPipVisible && !QGroundControl.videoManager.fullScreen
            width:          _mainIsMap ? _panel.width  : _pipSize
            height:         _mainIsMap ? _panel.height : _pipSize * (9/16)
            states: [
                State {
                    name:   "pipMode"
                    PropertyChanges {
                        target:             _flightMapContainer
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                    }
                },
                State {
                    name:   "fullMode"
                    PropertyChanges {
                        target:             _flightMapContainer
                        anchors.margins:    0
                    }
                }
            ]
            FlightDisplayViewMap {
                id:                         _flightMap
                anchors.fill:               parent
                planMasterController:       masterController
                guidedActionsController:    _guidedController
                flightWidgets:              flightDisplayViewWidgets
                rightPanelWidth:            ScreenTools.defaultFontPixelHeight * 9
                qgcView:                    root
                multiVehicleView:           !singleVehicleView.checked
                scaleState:                 (_mainIsMap && flyViewOverlay.item) ? (flyViewOverlay.item.scaleState ? flyViewOverlay.item.scaleState : "bottomMode") : "bottomMode"
            }
        }

        //-- Video View
        Item {
            id:             _flightVideo
            z:              _mainIsMap ? _panel.z + 2 : _panel.z + 1
            width:          !_mainIsMap ? _panel.width  : _pipSize
            height:         !_mainIsMap ? _panel.height : _pipSize * (9/16)
            anchors.left:   _panel.left
            anchors.bottom: _panel.bottom
            visible:        QGroundControl.videoManager.hasVideo && (!_mainIsMap || _isPipVisible)
            states: [
                State {
                    name:   "pipMode"
                    PropertyChanges {
                        target: _flightVideo
                        anchors.margins: ScreenTools.defaultFontPixelHeight
                    }
                    PropertyChanges {
                        target: _flightVideoPipControl
                        inPopup: false
                    }
                },
                State {
                    name:   "fullMode"
                    PropertyChanges {
                        target: _flightVideo
                        anchors.margins:    0
                    }
                    PropertyChanges {
                        target: _flightVideoPipControl
                        inPopup: false
                    }
                },
                State {
                    name: "popup"
                    StateChangeScript {
                        script: QGroundControl.videoManager.stopVideo()
                    }
                    ParentChange {
                        target: _flightVideo
                        parent: videoItem
                        x: 0
                        y: 0
                        width: videoWindow.width
                        height: videoWindow.height
                    }
                    PropertyChanges {
                        target: _flightVideoPipControl
                        inPopup: true
                    }
                },
                State {
                    name: "unpopup"
                    StateChangeScript {
                        script: QGroundControl.videoManager.stopVideo()
                    }
                    ParentChange {
                        target: _flightVideo
                        parent: _panel
                    }
                    PropertyChanges {
                        target: _flightVideo
                        anchors.left:       _panel.left
                        anchors.bottom:     _panel.bottom
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                    }
                    PropertyChanges {
                        target: _flightVideoPipControl
                        inPopup: false
                    }
                }
            ]
            //-- Video Streaming
            FlightDisplayViewVideo {
                id:             videoStreaming
                anchors.fill:   parent
                visible:        QGroundControl.videoManager.isGStreamer
            }
            //-- UVC Video (USB Camera or Video Device)
            Loader {
                id:             cameraLoader
                anchors.fill:   parent
                visible:        !QGroundControl.videoManager.isGStreamer
                source:         QGroundControl.videoManager.uvcEnabled ? "qrc:/qml/FlightDisplayViewUVC.qml" : "qrc:/qml/FlightDisplayViewDummy.qml"
            }
        }

        QGCPipable {
            id:                 _flightVideoPipControl
            z:                  _flightVideo.z + 3
            width:              _pipSize
            height:             _pipSize * (9/16)
            anchors.left:       _panel.left
            anchors.bottom:     _panel.bottom
            anchors.margins:    ScreenTools.defaultFontPixelHeight
            visible:            QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.fullScreen && _flightVideo.state != "popup"
            isHidden:           !_isPipVisible
            isDark:             isBackgroundDark
            enablePopup:        _mainIsMap
            onActivated: {
                _mainIsMap = !_mainIsMap
                setStates()
            }
            onHideIt: {
                setPipVisibility(!state)
            }
            onPopup: {
                videoWindow.visible = true
                _flightVideo.state = "popup"
            }
            onNewWidth: {
                _pipSize = newWidth
            }
        }

        Row {
            id:                     singleMultiSelector
            anchors.topMargin:      ScreenTools.toolbarHeight + _margins
            anchors.rightMargin:    _margins
            anchors.right:          parent.right
            anchors.top:            parent.top
            spacing:                ScreenTools.defaultFontPixelWidth
            z:                      _panel.z + 4
            visible:                QGroundControl.multiVehicleManager.vehicles.count > 1

            ExclusiveGroup { id: multiVehicleSelectorGroup }

            QGCRadioButton {
                id:             singleVehicleView
                exclusiveGroup: multiVehicleSelectorGroup
                text:           qsTr("Single")
                checked:        true
                color:          mapPal.text
            }

            QGCRadioButton {
                exclusiveGroup: multiVehicleSelectorGroup
                text:           qsTr("Multi-Vehicle")
                color:          mapPal.text
            }
        }

        FlightDisplayViewWidgets {
            id:                 flightDisplayViewWidgets
            z:                  _panel.z + 4
            height:             ScreenTools.availableHeight - (singleMultiSelector.visible ? singleMultiSelector.height + _margins : 0)
            anchors.left:       parent.left
            anchors.right:      altitudeSlider.visible ? altitudeSlider.left : parent.right
            anchors.bottom:     parent.bottom
            qgcView:            root
            useLightColors:     isBackgroundDark
            missionController:  _missionController
            visible:            singleVehicleView.checked && !QGroundControl.videoManager.fullScreen
        }

        //-------------------------------------------------------------------------
        //-- Loader helper for plugins to overlay elements over the fly view
        Loader {
            id:                 flyViewOverlay
            z:                  flightDisplayViewWidgets.z + 1
            visible:            !QGroundControl.videoManager.fullScreen
            height:             ScreenTools.availableHeight
            anchors.left:       parent.left
            anchors.right:      altitudeSlider.visible ? altitudeSlider.left : parent.right
            anchors.bottom:     parent.bottom

            property var qgcView: root
        }

        MultiVehicleList {
            anchors.margins:    _margins
            anchors.top:        singleMultiSelector.bottom
            anchors.right:      parent.right
            anchors.bottom:     parent.bottom
            width:              ScreenTools.defaultFontPixelWidth * 30
            visible:            !singleVehicleView.checked && !QGroundControl.videoManager.fullScreen
            z:                  _panel.z + 4
        }

        //-- Virtual Joystick
        Loader {
            id:                         virtualJoystickMultiTouch
            z:                          _panel.z + 5
            width:                      parent.width  - (_flightVideoPipControl.width / 2)
            height:                     Math.min(ScreenTools.availableHeight * 0.25, ScreenTools.defaultFontPixelWidth * 16)
            visible:                    (_virtualJoystick ? _virtualJoystick.value : false) && !QGroundControl.videoManager.fullScreen
            anchors.bottom:             _flightVideoPipControl.top
            anchors.bottomMargin:       ScreenTools.defaultFontPixelHeight * 2
            anchors.horizontalCenter:   flightDisplayViewWidgets.horizontalCenter
            source:                     "qrc:/qml/VirtualJoystick.qml"
            active:                     _virtualJoystick ? _virtualJoystick.value : false

            property bool useLightColors: isBackgroundDark

            property Fact _virtualJoystick: QGroundControl.settingsManager.appSettings.virtualJoystick
        }

        ToolStrip {
            visible:            (_activeVehicle ? _activeVehicle.guidedModeSupported : true) && !QGroundControl.videoManager.fullScreen
            id:                 toolStrip
            anchors.leftMargin: isInstrumentRight() ? ScreenTools.defaultFontPixelWidth : undefined
            anchors.left:       isInstrumentRight() ? _panel.left : undefined
            anchors.rightMargin:isInstrumentRight() ? undefined : ScreenTools.defaultFontPixelWidth
            anchors.right:      isInstrumentRight() ? undefined : _panel.right
            anchors.topMargin:  ScreenTools.toolbarHeight + (_margins * 2)
            anchors.top:        _panel.top
            z:                  _panel.z + 4
            title:              qsTr("Fly")
            maxHeight:          (_flightVideo.visible ? _flightVideo.y : parent.height) - toolStrip.y
            buttonVisible:      [ QGroundControl.settingsManager.appSettings.useChecklist.rawValue, _guidedController.showTakeoff || !_guidedController.showLand, _guidedController.showLand && !_guidedController.showTakeoff, true, true, true, _guidedController.smartShotsAvailable ]
            buttonEnabled:      [ QGroundControl.settingsManager.appSettings.useChecklist.rawValue, _guidedController.showTakeoff, _guidedController.showLand, _guidedController.showRTL, _guidedController.showPause, _anyActionAvailable, _anySmartShotAvailable ]

            property bool _anyActionAvailable: _guidedController.showStartMission || _guidedController.showResumeMission || _guidedController.showChangeAlt || _guidedController.showLandAbort
            property bool _anySmartShotAvailable: _guidedController.showOrbit
            property var _actionModel: [
                {
                    title:      _guidedController.startMissionTitle,
                    text:       _guidedController.startMissionMessage,
                    action:     _guidedController.actionStartMission,
                    visible:    _guidedController.showStartMission
                },
                {
                    title:      _guidedController.continueMissionTitle,
                    text:       _guidedController.continueMissionMessage,
                    action:     _guidedController.actionContinueMission,
                    visible:    _guidedController.showContinueMission
                },
                {
                    title:      _guidedController.resumeMissionTitle,
                    text:       _guidedController.resumeMissionMessage,
                    action:     _guidedController.actionResumeMission,
                    visible:    _guidedController.showResumeMission
                },
                {
                    title:      _guidedController.changeAltTitle,
                    text:       _guidedController.changeAltMessage,
                    action:     _guidedController.actionChangeAlt,
                    visible:    _guidedController.showChangeAlt
                },
                {
                    title:      _guidedController.landAbortTitle,
                    text:       _guidedController.landAbortMessage,
                    action:     _guidedController.actionLandAbort,
                    visible:    _guidedController.showLandAbort
                }
            ]
            property var _smartShotModel: [
                {
                    title:      _guidedController.orbitTitle,
                    text:       _guidedController.orbitMessage,
                    action:     _guidedController.actionOrbit,
                    visible:    _guidedController.showOrbit
                }
            ]

            model: [
                {
                    name:               "Checklist",
                    iconSource:         "/qmlimages/check.svg",
                    dropPanelComponent: checklistDropPanel
                },
                {
                    name:       _guidedController.takeoffTitle,
                    iconSource: "/res/takeoff.svg",
                    action:     _guidedController.actionTakeoff
                },
                {
                    name:       _guidedController.landTitle,
                    iconSource: "/res/land.svg",
                    action:     _guidedController.actionLand
                },
                {
                    name:       _guidedController.rtlTitle,
                    iconSource: "/res/rtl.svg",
                    action:     _guidedController.actionRTL
                },
                {
                    name:       _guidedController.pauseTitle,
                    iconSource: "/res/pause-mission.svg",
                    action:     _guidedController.actionPause
                },
                {
                    name:       qsTr("Action"),
                    iconSource: "/res/action.svg",
                    action:     -1
                },
                /*
                  No firmware support any smart shots yet
                {
                    name:       qsTr("Smart"),
                    iconSource: "/qmlimages/MapCenter.svg",
                    action:     -1
                },
                */
            ]

            onClicked: {
                guidedActionsController.closeAll()
                var action = model[index].action
                if (action === -1) {
                    if (index == 4) {
                        guidedActionList.model   = _actionModel
                        guidedActionList.visible = true
                    } else if (index == 5) {
                        guidedActionList.model   = _smartShotModel
                        guidedActionList.visible = true
                    }
                } else {
                    _guidedController.confirmAction(action)
                }
            }
        }

        GuidedActionsController {
            id:                 guidedActionsController
            missionController:  _missionController
            confirmDialog:      guidedActionConfirm
            actionList:         guidedActionList
            altitudeSlider:     _altitudeSlider
            z:                  _flightVideoPipControl.z + 1

            onShowStartMissionChanged: {
                if (showStartMission && !showResumeMission) {
                    confirmAction(actionStartMission)
                }
            }

            onShowContinueMissionChanged: {
                if (showContinueMission) {
                    confirmAction(actionContinueMission)
                }
            }

            onShowResumeMissionChanged: {
                if (showResumeMission) {
                    confirmAction(actionResumeMission)
                }
            }

            onShowLandAbortChanged: {
                if (showLandAbort) {
                    confirmAction(actionLandAbort)
                }
            }

            /// Close all dialogs
            function closeAll() {
                mainWindow.enableToolbar()
                rootLoader.sourceComponent  = null
                guidedActionConfirm.visible = false
                guidedActionList.visible    = false
                altitudeSlider.visible      = false
            }
        }

        GuidedActionConfirm {
            id:                         guidedActionConfirm
            anchors.margins:            _margins
            anchors.bottom:             parent.bottom
            anchors.horizontalCenter:   parent.horizontalCenter
            guidedController:           _guidedController
            altitudeSlider:             _altitudeSlider
        }

        GuidedActionList {
            id:                         guidedActionList
            anchors.margins:            _margins
            anchors.bottom:             parent.bottom
            anchors.horizontalCenter:   parent.horizontalCenter
            guidedController:           _guidedController
        }

        //-- Altitude slider
        GuidedAltitudeSlider {
            id:                 altitudeSlider
            anchors.margins:    _margins
            anchors.right:      parent.right
            anchors.topMargin:  ScreenTools.toolbarHeight + _margins
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            z:                  _guidedController.z
            radius:             ScreenTools.defaultFontPixelWidth / 2
            width:              ScreenTools.defaultFontPixelWidth * 10
            color:              qgcPal.window
            visible:            false
        }
    }

    Component {
        id: checklistDropPanel

        Rectangle {
            id:       checklist
            width:    mainColumn.width + (ScreenTools.defaultFontPixelWidth * 4)
            height:   (headerColumn.height+mainColumn.height) * 1.07
            color:    qgcPal.windowShade
            radius:   20
            enabled:  QGroundControl.multiVehicleManager.vehicles.count > 0;

            onBatPercentRemainingChanged: {if(_initialized) buttonBattery.updateItem();}
            onGpsLockChanged: {buttonSensors.updateItem();}

            // Connections
            Connections {
                target: _activeVehicle
                onUnhealthySensorsChanged: checklist.onUnhealthySensorsChanged();
                onEnergySystemFailureChanged: buttonEnergyBudgetWidget.updateItem();
            }
            Connections {
                target: QGroundControl.multiVehicleManager
                onActiveVehicleChanged: checklist.onActiveVehicleChanged();
                onActiveVehicleAvailableChanged: {}
            }
            Connections {
                target: QGroundControl.settingsManager.appSettings.audioMuted
                onValueChanged: buttonSoundOutput.updateItem(); //TODO(philippoe): We are binding to a signal which is explicitly marked as "only for QT internal use" here.
            }
            Component.onCompleted: {
                if(QGroundControl.multiVehicleManager.vehicles.count > 0) {
                    onActiveVehicleChanged();
                    _initialized=true;
                }
            }

            function updateVehicleDependentItems() {
                buttonSensors.updateItem();
                buttonBattery.updateItem();
                buttonRC.updateItem();
                buttonEstimator.updateItem();
                buttonEnergyBudgetWidget.updateItem();
            }
            function onActiveVehicleChanged() {
                buttonSoundOutput.updateItem();     // Just updated here for initialization once we connect to a vehicle
                onUnhealthySensorsChanged();        // The health states could all have changed - need to update them.
            }
            function onUnhealthySensorsChanged() {
                var unhealthySensorsStr = _activeVehicle.unhealthySensors;

                // Set to healthy per default
                for(var i=0;i<32;i++) _healthFlags[i]=true;

                for(i=0;i<unhealthySensorsStr.length;i++) { // TODO (philippoe): This is terrible, having this data available in the form of a bitfield would be much better than a string list!
                    switch(unhealthySensorsStr[i]) {
                    case "Gyro":                    _healthFlags[0]=false; break;
                    case "Accelerometer":           _healthFlags[1]=false; break;
                    case "Magnetometer":            _healthFlags[2]=false; break;
                    case "Absolute pressure":       _healthFlags[3]=false; break;
                    case "Differential pressure":   _healthFlags[4]=false; break;
                    case "GPS":                     _healthFlags[5]=false; break;
                    case "Optical flow":            _healthFlags[6]=false; break;
                    case "Computer vision position":_healthFlags[7]=false; break;
                    case "Laser based position":    _healthFlags[8]=false; break;
                    case "External ground truth":   _healthFlags[9]=false; break;
                    case "Angular rate control":    _healthFlags[10]=false; break;
                    case "Attitude stabilization":  _healthFlags[11]=false; break;
                    case "Yaw position":            _healthFlags[12]=false; break;
                    case "Z/altitude control":      _healthFlags[13]=false; break;
                    case "X/Y position control":    _healthFlags[14]=false; break;
                    case "Motor outputs / control": _healthFlags[15]=false; break;
                    case "RC receiver":             _healthFlags[16]=false; break;
                    case "Gyro 2":                  _healthFlags[17]=false; break;
                    case "Accelerometer 2":         _healthFlags[18]=false; break;
                    case "Magnetometer 2":          _healthFlags[19]=false; break;
                    case "GeoFence":                _healthFlags[20]=false; break;
                    case "AHRS":                    _healthFlags[21]=false; break;
                    case "Terrain":                 _healthFlags[22]=false; break;
                    case "Motors reversed":         _healthFlags[23]=false; break;
                    case "Logging":                 _healthFlags[24]=false; break;
                    case "Battery":                 _healthFlags[25]=false; break;
                    default:
                    }
                }
                updateVehicleDependentItems();
            }

            Column {
                id:         headerColumn
                x:          2*ScreenTools.defaultFontPixelWidth
                y:          2*ScreenTools.defaultFontPixelWidth
                width:      320
                spacing:    8

                // Header/title of checklist
                QGCLabel {anchors.horizontalCenter:   parent.horizontalCenter ; font.pointSize: ScreenTools.mediumFontPointSize ; text: _activeVehicle ? qsTr("Pre-flight checklist")+" (MAV ID:"+_activeVehicle.id+")" : qsTr("Pre-flight checklist (awaiting vehicle...)");}
                Rectangle {anchors.left:parent.left ; anchors.right:parent.right ; height:1 ; color:qgcPal.text}
            }

            Column {
                id:         mainColumn
                x:          2*ScreenTools.defaultFontPixelWidth
                anchors.top:headerColumn.bottom
                anchors.topMargin:ScreenTools.defaultFontPixelWidth
                width:      320
                spacing:    6
                enabled : QGroundControl.multiVehicleManager.vehicles.count > 0;
                opacity : 0.2+0.8*(QGroundControl.multiVehicleManager.vehicles.count > 0);

                // Checklist items: Standard
                QGCCheckListItem {
                    id: buttonHardware
                    name: "Hardware"
                    defaulttext: "Props mounted? Wings secured? Tail secured?"
                }

                QGCCheckListItem {
                     id: buttonBattery
                     name: "Battery"
                     pendingtext: "Healthy & charged > 40%. Battery connector firmly plugged?"
                     function updateItem() {
                         if (!_activeVehicle) {
                             _state = 0;
                         } else {
                             if (checklist._healthFlags[25] && batPercentRemaining>=40.0) _state = 1+3*(_nrClicked>0);
                             else {
                                 if(!checklist._healthFlags[25]) buttonBattery.failuretext="Not healthy. Check console.";
                                 else if(batPercentRemaining<40.0) buttonBattery.failuretext="Low (below 40%). Please recharge.";
                                 buttonBattery._state = 3;
                             }
                         }
                     }
                }

                QGCCheckListItem {
                    id: buttonEnergyBudgetWidget
                    name: "Power generation and storage"
                    defaulttext: "No data yet. Is the energy budget widget (see widgets menu) open?"
                    function updateItem() {
                        console.log("CLenergybudgetWidget::update | Batmon:",_activeVehicle.batmonFailure," MPPT: ",_activeVehicle.mpptFailure," Powerboard:",_activeVehicle.powerboardFailure);
                         if (!_activeVehicle) {
                             _state = 0;
                         } else {
                             if(_activeVehicle.batmonFailure==2 || _activeVehicle.powerboardFailure==2 || _activeVehicle.mpptFailure==2) {
                                 if(_activeVehicle.mpptFailure==2) failuretext="Maximum powerpoint tracker (MPPT) failure. Check console and energy widget."
                                 if(_activeVehicle.powerboardFailure==2) failuretext="Powerboard failure. Check console and energy widget."
                                 if(_activeVehicle.batmonFailure==2) failuretext="Battery monitoring system (BMS) failure. Check console and energy widget."
                                 _state = 3;
                             } else if(_activeVehicle.batmonFailure==1 || _activeVehicle.powerboardFailure==1 || _activeVehicle.mpptFailure==1) {
                                 var str="";
                                 if(_activeVehicle.mpptFailure==1) { str+="MPPT"; if(_activeVehicle.powerboardFailure==1 || _activeVehicle.batmonFailure==1) {str+=" and ";}}
                                 if(_activeVehicle.powerboardFailure==1) { str+="Powerboard"; if(_activeVehicle.batmonFailure==1) {str+=" and ";}}
                                 if(_activeVehicle.batmonFailure==1) { str+="Battery Monitoring System" }
                                 pendingtext=str+" issue(s). Check console and energy widget. Click to confirm you still want to launch despite the issue(s)."
                                 _state = 1 + 3*_nrClicked;
                             } else if (_activeVehicle.batmonFailure==-1 || _activeVehicle.powerboardFailure==-1 || _activeVehicle.mpptFailure==-1) {
                                 if (_activeVehicle.batmonFailure==-1 && _activeVehicle.powerboardFailure==-1 && _activeVehicle.mpptFailure==-1) {
                                     _state=0;
                                     _nrClicked=0;
                                 } else {
                                    if(_activeVehicle.mpptFailure==-1) {_state=1+_nrClicked*3; pendingtext="No updates from maximum powerpoint trackers (MPPTs). Check console and energy widget. Click if OK (e.g. because MPPTs are not installed)." }
                                    if(_activeVehicle.powerboardFailure==-1) {_state=1 ; pendingtext="No updates from powerboard. Check console and energy widget." }
                                    if(_activeVehicle.batmonFailure==-1) {_state=1 ; pendingtext="No updates from battery monitoring system (BMS). Check console and energy widget." }
                                 }
                             } else {
                                 _state = 4;
                             }
                         }
                     }
                }

                QGCCheckListItem {
                     id: buttonSensors
                     name: "Sensors"
                     function updateItem() {
                         if (!_activeVehicle) {
                             _state = 0;
                         } else {
                             if(checklist._healthFlags[0] &&
                                     checklist._healthFlags[1] &&
                                     checklist._healthFlags[2] &&
                                     checklist._healthFlags[3] &&
                                     checklist._healthFlags[4] &&
                                     checklist._healthFlags[5]) {
                                 if(!gpsLock) {
                                     buttonSensors.pendingtext="Pending. Waiting for GPS lock.";
                                     buttonSensors._state=1;
                                 } else {
                                     _state = 4; // All OK
                                 }
                             } else {
                                 if(!checklist._healthFlags[0]) failuretext="Failure. Gyroscope issues. Check console.";
                                 else if(!checklist._healthFlags[1]) failuretext="Failure. Accelerometer issues. Check console.";
                                 else if(!checklist._healthFlags[2]) failuretext="Failure. Magnetometer issues. Check console.";
                                 else if(!checklist._healthFlags[3]) failuretext="Failure. Barometer issues. Check console.";
                                 else if(!checklist._healthFlags[4]) failuretext="Failure. Airspeed sensor issues. Check console.";
                                 else if(!checklist._healthFlags[5]) failuretext="Failure. No valid or low quality GPS signal. Check console.";
                                 _state = 3;
                             }
                         }
                     }
                }
               QGCCheckListItem {
                    id: buttonRC
                    name: "Radio Control"
                    pendingtext: "Receiving signal. Perform range test & confirm."
                    failuretext: "No signal or invalid autopilot-RC config. Check RC and console."
                    function updateItem() {
                        if (!_activeVehicle) {
                            _state = 0;
                        } else {
                            if (_healthFlags[16]) {_state = 1+3*(_nrClicked>0);}
                            else {_state = 3;}
                        }
                    }
               }

               QGCCheckListItem {
                    id: buttonEstimator
                    name: "Global position estimate"
                    function updateItem() {
                        if (!_activeVehicle) {
                            _state = 0;
                        } else {
                            if (_healthFlags[21]) {_state = 4;}
                            else {_state = 3;}
                        }
                    }
               }

               QGCCheckListItem {
                    id: buttonSatcom
                    name: "Satellite Communication"
                    defaulttext: "Confirm the send and receive is working properly."
               }

               // Arming header
               //Rectangle {anchors.left:parent.left ; anchors.right:parent.right ; height:1 ; color:qgcPal.text}
               QGCLabel {anchors.horizontalCenter:parent.horizontalCenter ; text:qsTr("<i>Please arm the vehicle here.</i>")}
               //Rectangle {anchors.left:parent.left ; anchors.right:parent.right ; height:1 ; color:qgcPal.text}

              QGCCheckListItem {
                   id: buttonActuators
                   name: "Actuators"
                   group: 1
                   defaulttext: "Move all control surfaces. Did they work properly?"
              }

              QGCCheckListItem {
                   id: buttonMotors
                   name: "Motors"
                   group: 1
                   defaulttext: "Propellers free? Then throttle up gently. Working properly?"
              }

              QGCCheckListItem {
                   id: buttonMission
                   name: "Mission"
                   group: 1
                   defaulttext: "Please confirm mission is valid (waypoints valid, no terrain collision)."
              }

              QGCCheckListItem {
                   id: buttonSoundOutput
                   name: "Sound output"
                   group: 1
                   pendingtext: "QGC audio output enabled. System audio output enabled, too?"
                   failuretext: "Failure, QGC audio output is disabled. Please enable it under application settings->general to hear audio warnings!"
                   function updateItem() {
                       if (!_activeVehicle) {
                           _state = 0;
                       } else {
                           if (QGroundControl.settingsManager.appSettings.audioMuted.rawValue) {_state = 3;_nrClicked=0;}
                           else {_state = 1+3*(_nrClicked>0);}
                       }
                   }
              }

              // Directly before launch header
              //Rectangle {anchors.left:parent.left ; anchors.right:parent.right ; height:1 ; color:qgcPal.text}
              QGCLabel {anchors.horizontalCenter:parent.horizontalCenter ; text:qsTr("<i>Last preparations before launch</i>") ; opacity : 0.2+0.8*(_checkState >= 2);}
              //Rectangle {anchors.left:parent.left ; anchors.right:parent.right ; height:1 ; color:qgcPal.text}

              QGCCheckListItem {
                   id: buttonPayload
                   name: "Payload"
                   group: 2
                   defaulttext: "Configured and started?"
                   pendingtext: "Payload lid closed?"
              }

              QGCCheckListItem {
                   id: buttonWeather
                   name: "Wind & weather"
                   group: 2
                   defaulttext: "OK for your platform?"
                   pendingtext: "Launching into the wind?"
              }

              QGCCheckListItem {
                   id: buttonFlightAreaFree
                   name: "Flight area"
                   group: 2
                   defaulttext: "Launch area and path free of obstacles/people?"
              }

            } // Column

            property bool _initialized:false
            property var _healthFlags: []
            property int _checkState: _activeVehicle ? (_activeVehicle.armed ? 1 + (buttonActuators._state + buttonMotors._state + buttonMission._state + buttonSoundOutput._state) / 4 / 4 : 0) : 0 ; // Shows progress of checks inside the checklist - unlocks next check steps in groups
            property bool gpsLock: _activeVehicle ? _activeVehicle.gps.lock.rawValue>=3 : 0
            property var batPercentRemaining: _activeVehicle ? _activeVehicle.battery.getFact("percentRemaining").value : 0

            // TODO: Having access to MAVLINK enums (or at least QML consts) would be much cleaner than the code below
            property int subsystem_type_gyro : 1
            property int subsystem_type_acc : 2
            property int subsystem_type_mag : 4
            property int subsystem_type_abspressure : 8
            property int subsystem_type_diffpressure : 16
            property int subsystem_type_gps : 32
            property int subsystem_type_positioncontrol : 16384
            property int subsystem_type_motorcontrol : 32768
            property int subsystem_type_rcreceiver : 65536
            property int subsystem_type_ahrs : 2097152
            property int subsystem_type_terrain : 4194304
            property int subsystem_type_reversemotor : 8388608
            property int subsystem_type_logging : 16777216
            property int subsystem_type_sensorbattery : 33554432
            property int subsystem_type_rangefinder : 67108864
        } //Rectangle
    } //Component
} //QGC View
