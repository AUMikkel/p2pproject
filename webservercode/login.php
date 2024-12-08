<?php
header('Content-Type: application/json');

$host = "********";
$db = "dokkedalleth_dk_db_p2p";
$user = "dokkedalleth_dk";
$pass = "*****";

$conn = new mysqli($host, $user, $pass, $db);

if ($conn->connect_error) {
    echo json_encode(["success" => false, "error" => "Connection failed: " . $conn->connect_error]);
    exit();
}

// Get data from POST request
$data = json_decode(file_get_contents("php://input"), true);
$username = $data['username'] ?? null;
$password = $data['password'] ?? null;

// Validate input
if (empty($username) || empty($password)) {
    http_response_code(400); // Bad Request
    echo json_encode(["success" => false, "error" => "Missing username or password"]);
    exit();
}

// Check username and password
$sql = "SELECT id, username, email, profile_image_url, password_hash FROM users WHERE username = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $username);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 1) {
    $row = $result->fetch_assoc();
    if (password_verify($password, $row['password_hash'])) {
   
        echo json_encode([
            "success" => true,
            "user_id" => $row['id'],
            "username" => $row['username'], 
            "email" => $row['email'],
            "profileImageUrl" => $row['profile_image_url'] ?? "https://example.com/default-profile.jpg"
        ]);
    } else {
        http_response_code(401); // Unauthorized
        echo json_encode(["success" => false, "error" => "Invalid credentials"]);
    }
} else {
    http_response_code(401); // Unauthorized
    echo json_encode(["success" => false, "error" => "Invalid credentials"]);
}

$conn->close();
?>
