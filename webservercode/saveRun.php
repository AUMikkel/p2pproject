<?php
header('Content-Type: application/json');

// Database connection
$host = "*****";
$db = "dokkedalleth_dk_db_p2p";
$user = "dokkedalleth_dk";
$pass = "****";

$conn = new mysqli($host, $user, $pass, $db);

if ($conn->connect_error) {
    die(json_encode(["success" => false, "error" => "Connection failed: " . $conn->connect_error]));
}

// Get data from POST request
$data = json_decode(file_get_contents("php://input"), true);
$username = $data['username']; 
$start_time = $data['start_time'];
$end_time = $data['end_time'];
$total_distance = $data['total_distance'];
$activity_type = $data['activity_type'];
$route = $data['route'];
//$imu_data = json_encode($data['imu_data']);
$checkpoints = $data['checkpoints'] ?? null;
$checkpointsJson = json_encode($checkpoints);

$routeJson = json_encode($data['route']);

$username = $data['username'] ?? null;
$start_time = $data['start_time'] ?? null;
$end_time = $data['end_time'] ?? null;
$total_distance = $data['total_distance'] ?? null;



if (empty($username)){
  echo json_encode(["success" => false, "error" => "Missing username fields.", $username]);
    exit();
}

if (empty($start_time) || empty($end_time)){
  echo json_encode(["success" => false, "error" => "Missing send/endtime."]);
  exit();
}

if(empty($route)){
  echo json_encode(["success" => false, "error" => "Missing route/distance."]);
  exit();
}


// Check for valid total_distance (allow 0.0)
if (!is_numeric($total_distance) || $total_distance < 0) {
    echo json_encode(["success" => false, "error" => "Invalid total_distance."]);
    exit();
}

// Check if route is a valid array
if (!is_array($route) || count($route) == 0) {
    echo json_encode(["success" => false, "error" => "Invalid route data."]);
    exit();
}

if ($checkpointsJson === false) {
    echo json_encode(["success" => false, "error" => "Failed to encode JSON for checkpoints: " . json_last_error_msg()]);
    exit();
}



// Insert run data into the database
$sql = "INSERT INTO runs (start_time, end_time, total_distance, activity_type, route, username, checkpoints)
        VALUES (?, ?, ?, ?, ?, ?, ?)";
$stmt = $conn->prepare($sql);
$stmt->bind_param("sssssss", $start_time, $end_time, $total_distance, $activity_type, $routeJson, $username, $checkpointsJson);

if ($stmt->execute()) {
    echo json_encode(["success" => true, "run_id" => $stmt->insert_id]);
} else {
    echo json_encode(["success" => false, "error" => $stmt->error]);
}

$conn->close();
?>
