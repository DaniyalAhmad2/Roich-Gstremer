import cv2
import threading
import queue
import time
from ultralytics import YOLO

# Initialize YOLO model
model = YOLO("yolov8n.pt")
#model.to("cuda")  # Ensure the model is using GPU

# Define the optimized GStreamer pipeline for RICOH THETA camera
gst_pipeline = (
    "v4l2src device=/dev/video0 ! "
    "image/jpeg, width=1920, height=1080, framerate=30/1 ! "
    "jpegdec ! "
    "videoconvert ! "
    "video/x-raw,format=BGR ! "
    "queue max-size-buffers=1 leaky=downstream ! "
    "appsink drop=true max-buffers=1"
)
# Initialize Video Capture
cap = cv2.VideoCapture(gst_pipeline)
# cap = cv2.VideoCapture("Front-60fps.mp4")

if not cap.isOpened():
    raise IOError('Cannot open RICOH THETA camera')

# Set frame width and height to reduce resolution
#FRAME_WIDTH = 640
#FRAME_HEIGHT = 480
#cap.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_WIDTH)
#cap.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_HEIGHT)

# Thread-safe queue with max size 1 to hold the latest frame
frame_queue = queue.Queue(maxsize=1)

# Event to signal thread termination
stop_event = threading.Event()

def frame_capture():
    """Continuously capture frames from the camera and put them into the queue."""
    while not stop_event.is_set():
        ret, frame = cap.read()
        if not ret:
            print("Failed to grab frame")
            stop_event.set()
            break
        # Resize the frame to reduce processing time
        #frame = cv2.resize(frame, (FRAME_WIDTH, FRAME_HEIGHT))
        # Put the latest frame into the queue, overwrite if necessary
        if not frame_queue.empty():
            try:
                frame_queue.get_nowait()
            except queue.Empty:
                pass
        frame_queue.put(frame)

def frame_detection():
    """Continuously get frames from the queue and perform YOLOv8 inference."""
    
    while not stop_event.is_set():
        start_time = time.time()
        try:
            frame = frame_queue.get(timeout=1)  # Wait for a frame
        except queue.Empty:
            continue  # No frame available, continue waiting
        # Run inference
        results = model(frame)
        # Annotate frame
        annotated_frame = results[0].plot()
        # Display the frame
        cv2.imshow("YOLO Inference", annotated_frame)
        
        # Check for 'q' key press to exit
        if cv2.waitKey(1) & 0xFF == ord("q"):
            stop_event.set()
            break
        time_elapsed = time.time() - start_time
        print(f"Inference time: {time_elapsed:.5f} seconds")

# Create and start threads
capture_thread = threading.Thread(target=frame_capture, daemon=True)
detection_thread = threading.Thread(target=frame_detection, daemon=True)

capture_thread.start()
detection_thread.start()

try:
    # Keep the main thread alive while the other threads are running
    while not stop_event.is_set():
        capture_thread.join(timeout=0.1)
        detection_thread.join(timeout=0.1)
except KeyboardInterrupt:
    stop_event.set()

# Cleanup
cap.release()
cv2.destroyAllWindows()
