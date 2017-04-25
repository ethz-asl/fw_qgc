#ifndef AUTOTRIM_H
#define AUTOTRIM_H

#include <QWidget>
#include <QTime>
#include "UAS.h"
#include "QGCDockWidget.h"
#include "Vehicle.h"
#include "ui_AutoTrim.h"


namespace Ui {
    class AutoTrim;
}

class UASInterface;

class AutoTrim : public QGCDockWidget
{
	Q_OBJECT

public:
    explicit AutoTrim(const QString& title, QAction* action, QWidget *parent = 0);
    ~AutoTrim();

public slots:
    //Internal slots (pushbuttons and so on)
    void ConnectToActiveUAS(void);
    void StartTrim(void);
    void StopTrim(void);
    void SetTrimDataVMin(void);
    void SetTrimDataVNom(void);
    void SetTrimDataVMax(void);
		
	//External slots
    void OnAslctrlDataChanged(float uElev, float uAil, float uRud, float uThrot, float roll, float pitch, float yaw, float roll_ref, float pitch_ref,float h);
    void OnSpeedChanged(Vehicle* vehicle, double groundspeed, double airspeed);
    void OnSensPowerChanged(float volt, float currpb, float curr_1, float curr_2);

private:
    void SetTrimData(int velocityType);
    void ResetData(void);
    void UpdateElapsedTimeCounters(void);

private:
    Ui::AutoTrim *m_ui;

    bool bConnected;	// Connected to a UAS?
    bool bStarted;		// Data recording started?

    QTime tElapsedSinceStart;

    int n_u;
    float avg_uElev;
    float avg_uAil;
    float avg_uRud;
    float avg_uThrot;

    int n_att;
    float avg_roll;
    float avg_pitch;
    float yaw_Start;

    int n_airspeed;
    float avg_airspeed;

    int n_power;
    float avg_power;

    int n_h;
    float h_Start;
};

#endif // AUTOTRIM_H
