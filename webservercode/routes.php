<?php
header('Content-Type: application/json');

// Database connection
$host = "******";
$db = "dokkedalleth_dk_db_p2p";
$user = "dokkedalleth_dk";
$pass = "******";

$conn = new mysqli($host, $user, $pass, $db);

if ($conn->connect_error) {
    echo json_encode(["success" => false, "error" => "Connection failed: " . $conn->connect_error]);
    exit();
}

$username = isset($_GET['username']) ? $_GET['username'] : null;
$activity_type = isset($_GET['activity_type']) ? $_GET['activity_type'] : null;
$min_distance = isset($_GET['min_distance']) ? floatval($_GET['min_distance']) : 0;
$max_distance = isset($_GET['max_distance']) ? floatval($_GET['max_distance']) : null;

// Build SQL query
$sql = "SELECT runs.id, runs.username, runs.route,runs.checkpoints, runs.total_distance,runs.start_time, TIMESTAMPDIFF(SECOND, runs.start_time, runs.end_time) AS total_time
        FROM runs
        WHERE runs.total_distance >= ?";

// Add optional filters
$params = [];
$params[] = $min_distance;
$param_types = "d";

if ($username) {
    $sql .= " AND runs.username = ?";
    $params[] = $username;
    $param_types .= "s";
}
if ($activity_type) {
    $sql .= " AND runs.activity_type = ?";
    $params[] = $activity_type;
    $param_types .= "s";
}
if ($max_distance) {
    $sql .= " AND runs.total_distance <= ?";
    $params[] = $max_distance;
    $param_types .= "d";
}

// Prepare and execute the query
$stmt = $conn->prepare($sql);
if (!$stmt) {
    echo json_encode(["success" => false, "error" => $conn->error]);
    exit();
}

$stmt->bind_param($param_types, ...$params);
$stmt->execute();
$result = $stmt->get_result();

// Fetch routes
$routes = [];
while ($row = $result->fetch_assoc()) {
    $routes[] = [
        "id" => $row["id"],
        "username" => $row["username"],
        "total_distance" => $row["total_distance"],
        "total_time" => $row["total_time"],
        "route" => json_decode($row["route"]),
      	"checkpoints" => json_decode($row["checkpoints"]),
        "date" => $row["start_time"]
    ];
}

// Send response
echo json_encode(["success" => true, "routes" => $routes]);

$conn->close();
?>
