// Test the Launch To Orbit program.

runpath
  (
    "LaunchToOrbit V07.ks",
    100,                  // Orbital altitude (km).
    0,                    // Orbital inclination (degrees).
    "NORTH",              // Launch direction.
    "ZEROLIFT",           // Launch turn type "ZEROLIFT","LTS". 
    350,                    // Turn start altitude (m).
    5,                    // Turn pitchover (degrees).
    1,                    // Turn pitchover rate (degrees/s)
    -30,                    // Linear-tangent Steering turn final angle (deg)
    167,                   // Linear-tangent Steering turn duration (s). 
    10,                   // Steering duration (s).
    "PHYSICS",            // Warp type (NOWARP,RAILS,PHYSICS).
    5,                   // Launch countdown duration (s).
    "NOSYNC",             // Launch sync period.
    "CIRC"              // Circularization (CIRC,NOCIRC).
  ).