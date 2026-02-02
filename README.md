# Head Tracking Flight Simulator

A flight simulator controlled through head movements. The system uses a webcam and MediaPipe artificial intelligence to detect the position and tilt of the user's head, translating it into commands to control an airplane within a 3D environment built with Godot Engine.

## System Description

This application consists of two main components that communicate with each other. The first component is a Python script that handles video acquisition from the webcam and facial analysis using MediaPipe. The second component is the Godot game engine, which receives the tracking data and applies it to the airplane controls in the 3D scene.

The operation is based on a client-server architecture where Python acts as a WebSocket server, continuously processing video frames and sending head rotation data. Godot connects as a client and uses this data to update the airplane's position and orientation in real time.

## Technical Requirements

Before starting the application, it is necessary to have Python 3.8 or higher installed on the system. During installation on Windows, it is essential to select the option that adds Python to the system PATH, otherwise the application will not be able to locate the interpreter.

A working and available webcam is also required. The system must be able to access the webcam without conflicts with other applications. Verify that no other program is using the webcam before starting the simulator.

Godot Engine 4.6 or higher is required to run the graphical part of the project. The project uses modern Godot 4.x APIs and is not compatible with previous versions.

## Installation and Configuration

Installing Python dependencies can be done automatically or manually. For automatic installation on Windows, simply run the setup.bat file with a double click. The script will take care of verifying the presence of Python and installing all necessary libraries via pip.

On Linux or macOS systems, open a terminal in the PythonTracking folder and execute the command bash setup.sh after making the script executable with chmod +x setup.sh.

If the automatic scripts fail, manual installation is possible. Open a terminal or command prompt, navigate to the PythonTracking folder and install dependencies with the command pip install -r requirements.txt. The libraries that will be installed include mediapipe for facial detection, opencv-python for video processing, numpy for mathematical calculations, and websockets for communication with Godot.

On first launch, the Python script will automatically download the MediaPipe face detection model. This file is approximately 20 MB in size and will be saved locally for subsequent uses.

## Starting the Application

The recommended method to start the simulator is to open the project directly in Godot Engine. When the play button is pressed, Godot will automatically start the Python script in the background, wait for the WebSocket server to be ready, and establish the connection.

After a few seconds necessary for MediaPipe initialization and webcam opening, the system will be operational. If everything works correctly, a message will be displayed in the Godot console confirming the connection to the tracking server.

For debugging or testing purposes, it is also possible to manually start the Python script. On Windows use the command python head_tracking.py from the PythonTracking folder, while on Linux or macOS use python3 head_tracking.py. The server will listen on address ws://127.0.0.1:8765 and begin processing frames from the webcam.

## Calibration System

Before being able to use the simulator effectively, it is essential to perform the calibration procedure. This step allows the system to adapt to the individual characteristics of the user, such as the natural amplitude of head movements and the rest position.

To start calibration, press the C key at any time during execution. An interface will appear that will guide the user through two distinct phases.

The first phase consists of defining the central reference position. The user must position themselves comfortably in front of the webcam, assume a natural posture with head straight and gaze directed straight at the screen. When ready, press the spacebar to register this position as the zero point.

The second phase requires the user to perform the full range of movements they intend to use during the game. Move your head up and down to define the altitude control range, and tilt it right and left to calibrate steering control. It is important to perform wide but comfortable movements, as these will define the maximum control limits.

During this phase, the interface will show in real time the minimum and maximum values recorded for each movement axis. When satisfied with the amplitude of movements tested, press the spacebar again to complete calibration.

Once the procedure is finished, the system will automatically normalize all input values between minus one and plus one, ensuring precise and proportional control of the airplane.

## Game Controls

The control system is based on three fundamental parameters extracted from the head position. Pitch represents the vertical tilt of the head, obtained by lowering the head toward the chest or raising it upward. Roll indicates lateral tilt, like when resting your head on a shoulder. Yaw, although detected, is not currently used in the controls.

To control the airplane, vertical head movement governs altitude. Raising your head makes the plane climb, while lowering it makes it descend. Lateral head tilt controls direction instead, with head tilted left making it turn left and vice versa.

To accelerate the airplane it is necessary to hold down the spacebar. When the plane is on the ground, acceleration moves the aircraft horizontally on the runway. Once in flight, acceleration maintains a constant forward speed, allowing the user to concentrate on directional control through head movements.

The ESC key allows closing the calibration interface if active, while pressing C again allows recalibration at any time.

## Technical Architecture

The Python component uses MediaPipe Face Landmarker to identify 468 reference points on the user's face. Of these, six specific points are used to calculate the three-dimensional orientation of the head through OpenCV's solvePnP algorithm. This Perspective-n-Point method estimates head pose by solving the correspondence between 2D points in the image and a generic 3D model of the human face.

The three rotation angles are extracted from the resulting rotation matrix and converted to degrees. Pitch and yaw are calculated directly from the matrix decomposition, while roll is determined by analyzing the tilt of the line connecting the eyes.

This data is serialized in JSON format and transmitted via WebSocket to all connected clients. The protocol uses an asynchronous loop that maintains approximately 30 frames per second, balancing responsiveness and computational load.

On the Godot side, the godot_client.gd script manages the WebSocket connection lifecycle. At startup, it creates a separate process for the Python script and waits five seconds to give the server time to fully initialize. Subsequently, it attempts connection to the local server on port 8765.

The received data is deserialized and stored in global variables accessible from any node in the scene. The calibration system transforms these raw values into normalized inputs using the previously recorded ranges. This approach ensures that physically different movements between users produce the same effect on airplane control.

The airplane.gd script finally applies these normalized inputs to the aircraft physics. The system distinguishes between ground and flight states through raycasts positioned in the wheels. When the plane is on the ground, physics limits movement to the horizontal plane and applies greater friction. In flight, head controls directly influence the aircraft rotation on pitch and roll, creating a natural and intuitive flight experience.

## Troubleshooting

If at launch an error related to Python's absence is displayed, verify that Python is correctly installed and present in the system PATH. On Windows, it may be necessary to reinstall Python by explicitly selecting the PATH addition option.

If the webcam is not detected or does not start, check that no other application is using the device. Applications like Skype, Teams or OBS could block webcam access. Additionally, on Windows systems it may be necessary to grant webcam permissions in the operating system's privacy settings.

If ModuleNotFoundError type errors appear during Python script execution, it means some dependencies were not installed correctly. Re-run the setup script or manually install missing packages with the command pip install mediapipe opencv-python numpy websockets requests.

In case of imprecise or unresponsive airplane movements, the problem likely resides in inadequate calibration. Repeat the calibration procedure paying attention to perform wide and deliberate movements during the second phase, making sure to explore the full range of motion you intend to use.

If the WebSocket connection fails repeatedly, verify that no firewall or antivirus software is blocking communication on port 8765. Also check that the Python script is actually running by verifying the process presence in the operating system's task manager.

## Technical Notes

The MediaPipe model is automatically downloaded from Google's official repository on first launch and saved in the PythonTracking folder. This process requires an active internet connection only the first time.

The tracking system maintains a minimal state history to ensure smoothness even in case of brief tracking losses. If the face is not detected for some frames, previous values are maintained to avoid sudden jerks.

WebSocket communication is designed to support multiple simultaneous connections, although currently the application uses a single Godot instance. This architecture allows future extensions such as multiplayer or separate debug visualizations.

The project uses Jolt Physics as the 3D physics engine in Godot, configured through project settings to guarantee realistic simulations of airplane behavior during flight and contact with the ground.
