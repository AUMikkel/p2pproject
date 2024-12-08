# p2prunningapp

**Running is a healthy hobby, but it can be hard to stay motivated.**

This app is designed to make running more engaging by allowing you to compete against a "ghost" runner. The ghost can represent either your own previously recorded run or another user's run, providing real-time tracking and feedback to let you know if you’re ahead or behind.

## Features
- **Real-Time Competition:** Track your pace and speed against a ghost and get vocal updates to stay on track.
- **IoT Integration:** Connect to a wristwatch IoT device via Bluetooth Low Energy (BLE).
    - The watch displays:
        - Your elapsed time
        - Your current pace
        - The ghost's pace
    - Tracks precise movement with IMU (Inertial Measurement Unit) and GPS.
- **Cloud Integration:** Upload your runs to a server and store them in a database for future reference or competition.
- **Web Interface:** Share and view runs on [app.dokkedalleth.dk](http://app.dokkedalleth.dk).
- **Tracking:** Uses GPS to track your route, distance and pace.

## Goals
1. **Accessibility:** Explore the potential of usruteing low-cost IoT devices for fitness tracking, making it an affordable option for users.
2. **Performance Testing:** Evaluate:
    - Ability to run against a ghost and receive vocal updates.
    - Accuracy of distance and pace tracking compared to expensive smartwatches.
    - BLE transmission delays and their impact on functionality.
3. **Battery Efficiency:** Implement BLE communication to optimize power consumption for extended usage.

## Getting Started
- **Mobile App:** Track your runs and sync data to the cloud.
- **IoT Watch:** M5StiCk PLUS device for real-time stats and IMU data collection.
- **Web Platform:** Access runs and leaderboards online.

## Project Inspiration
This project draws from the **_Building the Internet of Things with P2P and Cloud Computing_** course, leveraging IoT principles to create a robust and innovative fitness tracking ecosystem.

By combining affordable technology, real-time feedback, and online competition, this app aims to make running more fun and engaging for everyone!
